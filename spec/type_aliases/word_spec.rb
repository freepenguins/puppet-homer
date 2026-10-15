# frozen_string_literal: true

require 'spec_helper'

describe 'Homer::Word' do
  it { is_expected.to allow_value('eth0') }
  it { is_expected.to allow_value('10.0.0.5:9060,10.0.0.6:9060') }
  it { is_expected.to allow_value('-hi') }
  it { is_expected.not_to allow_value('') }
  it { is_expected.not_to allow_value('-hi 2002') }
  it { is_expected.not_to allow_value("eth0\n") }
end
