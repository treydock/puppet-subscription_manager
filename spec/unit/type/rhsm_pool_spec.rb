#!/usr/bin/ruby -S rspec
# frozen_string_literal: true

#
#  Test the rhsm_pool type
#
#   Copyright 2016 WaveClaw <waveclaw@hotmail.com>
#
#   See LICENSE for licensing.
#

require 'spec_helper'

# Example:
#  rhsm_pool { '1a2b3c4d5e6f1234567890abcdef12345':
#    name              => 'Extra Packages for Enterprise Linux',
#    ensure            => present,
#    provides          => 'EPEL',
#    sku               => 1234536789012,
#    contract          => 'Fancy Widgets, LTD',
#    account           => '1234-12-3456-0001',
#    serial            => '1234567890123456789',
#    id                => 1a2b3c4d5e6f1234567890abcdef12345,
#    active            => true,
#    quantity_used     => 1,
#    service_level     => 'STANDARD',
#    service_type      => 'EOL',
#    status_details    => 'expired',
#    subscription_type => 'permanent',
#    starts            => 06/01/2015,
#    ends              => 05/24/2045,
#    system_type       => physical,
# }

described_class = Puppet::Type.type(:rhsm_pool)

describe described_class, '#rhsm_pool.type' do
  # only works if you define the feature in the type, json is a Puppet-wide one
  # it "should have a json feature" do
  #   expect(described_class.provider_feature(:json)).to_not be_nil
  # end

  [:subscription_name, :ensure, :provides, :sku, :contract, :account, :serial,
   :active, :quantity_used, :service_level, :service_type,
   :status_details, :subscription_type, :starts, :ends, :system_type].each do |property|
    context "for #{property}" do
      it 'is of type property' do
        expect(described_class.attrtype(property))
          .to eq(:property)
      end
      it 'is of class property' do
        expect(described_class.attrclass(property).ancestors)
          .to include(Puppet::Property)
      end
      it 'has documentation' do
        expect(described_class.attrclass(property).doc.strip)
          .not_to be_empty
      end
    end
  end

  context 'for Pool ID' do
    namevar = :id
    it 'is a parameter' do
      expect(described_class.attrtype(namevar)).to eq(:param)
    end
    it 'has documentation' do
      expect(described_class.attrclass(namevar).doc.strip)
        .not_to be_empty
    end
    it 'is the namevar' do
      expect(described_class.key_attributes).to eq([namevar])
    end
    it 'returns a name equal to this parameter' do
      resource = described_class.new(
        namevar => '123',
      )
      expect(resource[namevar]).to eq('123')
      expect(resource[:name]).to eq('123')
    end
    it 'rejects invalid values' do
      expect { described_class.new(namevar => '@#_$)=') }
        .to raise_error(Puppet::ResourceError, %r{.*})
    end
    it 'accepts hex values' do
      value = '1234abcdefABDCF'
      resource = described_class.new(namevar => value)
      expect(resource[namevar]).to eq(value)
      expect(resource[:name]).to eq(value)
    end
  end

  it 'supports enabled' do
    resource = described_class.new(
      id: '123abc', ensure: :absent,
    )
    expect(resource[:ensure]).to eq(:absent)
  end

  [:starts, :ends].each do |dates|
    context "for #{dates}" do
      it 'has documentation for the property' do
        expect(described_class.attrclass(dates).doc.strip).not_to be_empty
      end
      it 'accepts date objects' do
        testdate = Date.parse('01/01/2000')
        resource = described_class.new(:id => '123abc', dates => testdate)
        expect(resource[dates]).to eq(testdate)
      end
      it 'rejects non-dates' do
        expect { described_class.new(:id => '123abc', dates => 'bad date') }
          .to raise_error(Puppet::ResourceError, %r{.*})
      end
      it 'coverts date-like strings to date objects' do
        testdate = '01/01/2000'
        resource = described_class.new(:id => '123abc', dates => testdate)
        expect(resource[dates]).to eq(Date.parse(testdate))
      end
    end
  end
end
