require 'spec_helper'

describe 'drbd::base' do

  let :pre_condition do
    "Exec { path => '/foo', }"
  end

  let(:facts) {{
    :architecture      => 'x86_64',
    :kernelrelease     => '2.6.32-431.11.2.el6.x86_64',
    :lsbmajdistrelease => 6,
    :operatingsystem   => 'RedHat',
    :osfamily          => 'RedHat',
    :virtual           => 'physical',
  }}

  it { should compile.with_all_deps }

end
