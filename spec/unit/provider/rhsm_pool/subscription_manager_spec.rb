#!/usr/bin/ruby -S rspec
# frozen_string_literal: true

#
#  Test the subscrption_manager provider for rhsm_pool
#
#   Copyright 2016 WaveClaw <waveclaw@hotmail.com>
#
#   See LICENSE for licensing.
#

require 'puppet'
require 'date'
require 'spec_helper'
require 'puppet/type/rhsm_pool'

# notes:
#  - end year is purposefuly abbreviated and beyond the UNIX 32-bit epoch
#  - is an _expired_ service even though ends is most likely in your future
raw_data = <<-EOD
Subscription Name: Extra Packages for Enterprise Linux
Provides:          Extra Packages for Enterprise Linux
SKU:               1234536789012
Contract:          Fancy Widgets, LTD
Account:           1234-12-3456-0001
Serial:            1234567890123456789
Pool ID:           1a2b3c4d5e6f1234567890abcdef12345
Active:            True
Quantity Used:     1
Service Level:     STANDARD
Service Type:      EOL
Status Details:    expired
Subscription Type: permanent
Starts:            06/01/2015
Ends:              05/24/38
System Type:       Physical
EOD

title1 = '1a2b3c4d5e6f1234567890abcdef12345'
title2 = '1234abc'

properties = {
  id: '1a2b3c4d5e6f1234567890abcdef12345',
  subscription_name: 'Extra Packages for Enterprise Linux',
  ensure: :present,
  provides: 'Extra Packages for Enterprise Linux',
  sku: '1234536789012',
  contract: 'Fancy Widgets, LTD',
  account: '1234-12-3456-0001',
  serial: '1234567890123456789',
  active: true,
  quantity_used: 1,
  service_level: 'STANDARD',
  service_type: 'EOL',
  status_details: 'expired',
  subscription_type: 'permanent',
  starts: Date.strptime('06/01/2015', '%m/%d/%Y'), # US Locale?
  ends: Date.strptime('05/24/2038', '%m/%d/%Y'), # UNIX 2038?
  system_type: 'Physical',
  provider: :subscription_manager
}

provider_class = Puppet::Type.type(:rhsm_pool).provider(:subscrption_manager)

describe provider_class, '#rhsm_pool.provider' do
  let(:resource) do
    Puppet::Type.type(:rhsm_pool).new(properties)
  end

  let(:provider) do
    resource.provider
  end

  let(:instance) do
    provider.class.instances.first
  end

  before :each do
    allow(provider.class).to receive(:suitable?).and_return(true)
    allow(Puppet::Util).to receive(:which).with('subscription-manager').and_return('subscription-manager')
  end

  after :each do
  end

  it 'has a resource from a generic list of propeties' do
    expect(resource).not_to eq(nil)
  end

  it 'has a provider for a generic resource' do
    expect(provider).not_to eq(nil)
  end

  [:create, :destroy, :exists?].each do |action|
    it "should respond to #{action}" do
      expect(provider).to respond_to(action)
    end
  end

  [:consumed_pools, :instances, :prefetch].each do |action|
    it "should respond to #{action}" do
      expect(provider.class).to respond_to(action)
    end
  end

  describe 'when parsing instances' do
    it 'instances should exist and be callable' do
      expect(provider.class).to respond_to(:instances)
    end
    it 'returns nothing for an empty list' do
      expect(provider.class).to receive(:subscription_manager).with(
        'list', '--consumed'
      ).and_return('')
      pools = provider.class.instances
      expect(pools.size).to eq(0)
    end
    it 'returns just one pool for a single input' do
      expect(provider.class).to receive(:subscription_manager).with(
        'list', '--consumed'
      ).and_return(raw_data)
      pools = provider.class.instances
      expect(pools.size).to eq(1)
    end
    it 'correctlies parse a list of pools' do
      pool_list = raw_data + "\n" + raw_data.gsub(title1, title2)
      expect(provider.class).to receive(:subscription_manager).with(
        'list', '--consumed'
      ).and_return(pool_list)
      pools = provider.class.instances
      expect(pools.size).to eq(2)
      expect(pools[0]).to be_exists
      expect(pools[0].id).to eq(title1)
      expect(pools[1]).to be_exists
      expect(pools[1].id).to eq(title2)
    end
    context 'should parse the expected values for properties' do
      properties.keys.each do |key|
        it "such as the #{key} property" do
          expect(provider.class).to receive(:subscription_manager).with(
            'list', '--consumed'
          ).and_return(raw_data)
          pools = provider.class.instances
          pool = pools[0]
          expect(pool).to respond_to(key)
          expect(pool.public_send(key)).to eq(resource[key])
        end
      end
    end
    context 'should not truncate centuries' do
      before :each do
        allow(provider.class).to receive(:subscription_manager).with(
          'list', '--consumed'
        ).and_return(raw_data)
      end
      it 'on the starts property' do
        expect(provider.class.instances[0].starts.year).to eq(2015)
      end
      it 'on the ends property' do
        expect(provider.class.instances[0].ends.year).to eq(2038)
      end
    end
  end

  describe 'self.prefetch' do
    it 'exists as a method' do
      expect(provider.class).to respond_to(:prefetch)
    end
    it 'can be called on the provider' do
      expect(provider.class).to receive(:subscription_manager).with(
        'list', '--consumed'
      ).and_return(raw_data)
      provider.class.prefetch(properties)
    end
  end

  context 'ensure' do
    it 'exists? should return false when the resource is absent' do
      provider.set(ensure: :absent)
      expect(provider).not_to be_exists
    end
    it 'exists? should return true when the resource is present' do
      provider.set(ensure: :present)
      expect(provider).to be_exists
    end
    it 'create should attach to a pool that should exist' do
      expect(provider).to receive(:subscription_manager).with(
        'attach', '--pool', title1
      )
      Puppet::Type.type(:rhsm_pool).new(name: title1,
                                        ensure: :present, provider: provider)
      allow(provider).to receive(:exists?).and_return(true)
      provider.create
    end
    it "destroy should detach from a pool that shouldn't exist" do
      serial = '1234567890123456789'
      expect(provider).to receive(:subscription_manager).with(
        'remove', '--serial', serial
      )
      Puppet::Type.type(:rhsm_pool).new(
        name: title1,
        ensure: :absent,
        serial: serial,
        provider: provider,
      )
      allow(provider).to receive(:exists?).and_return(false)
      provider.destroy
    end
  end
end
