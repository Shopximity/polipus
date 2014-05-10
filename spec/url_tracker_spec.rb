require "spec_helper"
require "polipus/url_tracker"
require "polipus/url_tracker/cached"

describe Polipus::UrlTracker do
  before(:all) do
    @bf = Polipus::UrlTracker.bloomfilter
    @set = Polipus::UrlTracker.redis_set
  end

  after(:all) do
    @bf.clear
    @set.clear
  end

  it 'should work (bf)' do
    url = "http://www.asd.com/asd/lol"
    @bf.visit url
    @bf.visited?(url).should be_true
    @bf.visited?("http://www.google.com").should be_false
  end

  it 'should work (redis_set)' do
    url = "http://www.asd.com/asd/lol"
    @set.visit url
    @set.visited?(url).should be_true
    @set.visited?("http://www.google.com").should be_false
  end

  describe Polipus::UrlTracker::Cached do

    unless defined? Polipus::UrlTracker::Mock
      class Polipus::UrlTracker::Mock
        attr_reader :options

        def initialize(options = {})
          @options = options
        end

        def visited?(url)
        end

        def visit(url)
        end

        def remove(url)
        end

        def clear
        end
      end
    end

    let(:url) { 'http://example.com' }

    subject { Polipus::UrlTracker.cached :tracker => :mock, :options => {:foo => :bar} }

    its(:tracker) { should be_kind_of Polipus::UrlTracker::Mock }
    its('tracker.options') { should == {:foo => :bar} }

    it 'forwards #visit to tracker' do
      flexmock(subject.tracker).should_receive(:visit).with(url)
      subject.visit url
    end

    it 'forwards #remove to tracker' do
      flexmock(subject.tracker).should_receive(:remove).with(url)
      subject.remove url
    end

    it 'forwards #clear to tracker' do
      flexmock(subject.tracker).should_receive(:clear)
      subject.clear
    end

    it 'calls the tracker when a URL has not been visited' do
      flexmock(subject.tracker).should_receive(:visited?).with(url).once()
      subject.visited?(url)
    end

    it 'does not call the tracker when a URL has been visited' do
      subject.visit(url)
      flexmock(subject.tracker).should_receive(:visited?).never()
      subject.visited?(url)
    end

    it 'caches when URLs have been visited' do
      flexmock(subject.tracker).should_receive(:visited?).with(url).and_return(true).once()

      subject.visited?(url)
      subject.visited?(url)
    end

    it 'does not cache when URLs have not been visited' do
      flexmock(subject.tracker).should_receive(:visited?).with(url).and_return(false).twice()

      subject.visited?(url)
      subject.visited?(url)
    end

  end
end
