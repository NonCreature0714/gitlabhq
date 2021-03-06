require 'spec_helper'

describe Gitlab::Git::Storage::NullCircuitBreaker do
  let(:storage) { 'default' }
  let(:hostname) { 'localhost' }
  let(:error) { nil }

  subject(:breaker) { described_class.new(storage, hostname, error: error) }

  context 'with an error' do
    let(:error) { Gitlab::Git::Storage::Misconfiguration.new('error') }

    describe '#perform' do
      it { expect { breaker.perform { 'ok' } }.to raise_error(error) }
    end

    describe '#circuit_broken?' do
      it { expect(breaker.circuit_broken?).to be_truthy }
    end

    describe '#last_failure' do
      it { Timecop.freeze { expect(breaker.last_failure).to eq(Time.now) } }
    end

    describe '#failure_count' do
      it { expect(breaker.failure_count).to eq(breaker.failure_count_threshold) }
    end

    describe '#failure_info' do
      it { Timecop.freeze { expect(breaker.failure_info).to eq(Gitlab::Git::Storage::CircuitBreaker::FailureInfo.new(Time.now, breaker.failure_count_threshold)) } }
    end
  end

  context 'not broken' do
    describe '#perform' do
      it { expect(breaker.perform { 'ok' }).to eq('ok') }
    end

    describe '#circuit_broken?' do
      it { expect(breaker.circuit_broken?).to be_falsy }
    end

    describe '#last_failure' do
      it { expect(breaker.last_failure).to be_nil }
    end

    describe '#failure_count' do
      it { expect(breaker.failure_count).to eq(0) }
    end

    describe '#failure_info' do
      it { expect(breaker.failure_info).to eq(Gitlab::Git::Storage::CircuitBreaker::FailureInfo.new(nil, 0)) }
    end
  end

  describe '#failure_count_threshold' do
    it { expect(breaker.failure_count_threshold).to eq(1) }
  end

  it 'implements the CircuitBreaker interface' do
    ours = described_class.public_instance_methods
    theirs = Gitlab::Git::Storage::CircuitBreaker.public_instance_methods

    # These methods are not part of the public API, but are public to allow the
    # CircuitBreaker specs to operate. They should be made private over time.
    exceptions = %i[
      cache_key
      check_storage_accessible!
      no_failures?
      storage_available?
      track_storage_accessible
      track_storage_inaccessible
    ]

    expect(theirs - ours).to contain_exactly(*exceptions)
  end
end
