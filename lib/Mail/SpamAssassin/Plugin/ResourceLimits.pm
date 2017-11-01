# <@LICENSE>
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to you under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# </@LICENSE>

=head1 NAME

Mail::SpamAssassin::Plugin::ResourceLimits - Limit the memory and/or CPU of child spamd processes

=head1 SYNOPSIS

  # This plugin is for admin only and cannot be specified in user config.
  loadplugin     Mail::SpamAssassin::Plugin::ResourceLimits

  # Sets to RLIMIT_CPU from BSD::Resource. The quota is based on max CPU Time seconds.
  resource_limit_cpu 120

  # Sets to RLIMIT_RSS and RLIMIT_AS via BSD::Resource.
  resource_limit_cpu 536870912

=head1 DESCRIPTION

This module leverages BSD::Resource to assure your spamd child processes do not exceed
specified CPU or memory limit. If this happens, the child process will die.
See the L<BSD::Resource> for more details.

NOTE: Because this plugin uses BSD::Resource, it will not function on Windows.

=head1 ADMINISTRATOR SETTINGS

=over 4

=item resource_limit_cpu 120	(default: 0 or no limit)

How many cpu cycles are allowed on this process before it dies.

=item resource_limit_mem 536870912	(default: 0 or no limit)

The maximum number of bytes of memory allowed both for:

=over

=item *

(virtual) address space bytes

=item *

resident set size

=back

=back

=cut

package Mail::SpamAssassin::Plugin::ResourceLimits;

use Mail::SpamAssassin::Plugin ();
use Mail::SpamAssassin::Logger ();
use Mail::SpamAssassin::Util   ();
use Mail::SpamAssassin::Constants qw(:sa);

use strict;
use warnings;

use BSD::Resource qw(RLIMIT_RSS RLIMIT_AS RLIMIT_CPU);

our @ISA = qw(Mail::SpamAssassin::Plugin);

sub new {
    my $class        = shift;
    my $mailsaobject = shift;

    $class = ref($class) || $class;
    my $self = $class->SUPER::new($mailsaobject);
    bless( $self, $class );

    $self->set_config( $mailsaobject->{conf} );
    return $self;
}

sub set_config {
    my ( $self, $conf ) = @_;
    my @cmds = ();

    push(
        @cmds,
        {
            setting  => 'resource_limit_mem',
            is_admin => 1,
            default  => '0',
            type     => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
        }
    );

    push(
        @cmds,
        {
            setting  => 'resource_limit_cpu',
            is_admin => 1,
            default  => '0',
            type     => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
        }
    );

    $conf->{parser}->register_commands( \@cmds );
}

sub spamd_child_init {
    my ($self) = @_;

    # Set CPU Resource limits if they were specified.
    Mail::SpamAssassin::Util::dbg("resourcelimitplugin: In spamd_child_init");
    Mail::SpamAssassin::Util::dbg( "resourcelimitplugin: cpu limit: " . $self->{main}->{conf}->{resource_limit_cpu} );
    if ( $self->{main}->{conf}->{resource_limit_cpu} ) {
        BSD::Resource::setrlimit( RLIMIT_CPU, $self->{main}->{conf}->{resource_limit_cpu}, $self->{main}->{conf}->{resource_limit_cpu} )
          || info("resourcelimitplugin: Unable to set RLIMIT_CPU");
    }

    # Set  Resource limits if they were specified.
    Mail::SpamAssassin::Util::dbg( "resourcelimitplugin: mem limit: " . $self->{main}->{conf}->{resource_limit_mem} );
    if ( $self->{main}->{conf}->{resource_limit_mem} ) {
        BSD::Resource::setrlimit( RLIMIT_RSS, $self->{main}->{conf}->{resource_limit_mem}, $self->{main}->{conf}->{resource_limit_mem} )
          || info("resourcelimitplugin: Unable to set RLIMIT_RSS");
        BSD::Resource::setrlimit( RLIMIT_AS, $self->{main}->{conf}->{resource_limit_mem}, $self->{main}->{conf}->{resource_limit_mem} )
          || info("resourcelimitplugin: Unable to set RLIMIT_AS");
    }
}

1;
