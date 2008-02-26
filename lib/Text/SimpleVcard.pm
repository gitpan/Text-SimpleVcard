# ===========================================================================
# Text::SimpleVproperty - a package to manage a single vCard-property
# ===========================================================================
package Text::SimpleVproperty;

use warnings;
use strict;

my @telTypes = qw( PREF WORK HOME VOICE FAX MSG CELL PAGER BBS MODEM CAR ISDN VIDEO);

# ---------------------------------------------------------------------------
# Check if a value is element of an array
# ---------------------------------------------------------------------------
sub isIn {
   my $val = shift;
   return( scalar grep( /^$val$/, @_) > 0);
}

sub new {
   my( $class, $data) = @_;
   my $self = {};

   my ( $meta, $val) = ( $data =~ /(.*?):(.*)/);
   my @meta = split( /;/, $meta);
   $self->{ name} = uc( shift( @meta));

   foreach( @meta){
      my( $key, $val) = split( /\s*=\s*/);

      if( $self->{ name} eq 'TEL' and isIn( $key, @telTypes)) {
	 $val = $key;
	 $key = 'TYPE';
      }

      if( $key eq 'TYPE') {
	 push( @{$self->{ types}}, $val) if( !isIn( $val, @{$self->{ types}}));
      } else {
	 ${ $self->{ param}}{ $key} = $val;
      }
   }
   $self->{ val} = $val;

   bless( $self, $class);
}

sub hasType {
   my( $class, $typ) = @_;

   return isIn( uc( $typ), @{ $class->{ types}});
}

sub sprint {
   my( $class) = @_;
   my $res = "$class->{ name}";

   print "Hugo 1: res=$res\n";
   foreach( @{ $class->{ types}}) {
      $res .= ";TYPE=$_";
   }
   foreach( keys %{ $class->{ param}}) {
      my $val = ${ $class->{ param}}{ $_};
      $res .= ";$_" . ( defined( $val) ? "=$val" : "");
   }
   $res .= ":$class->{ val}";
   print "Hugo 2: res=$res\n";
   return $res;
}

sub print {
   my( $class) = @_;

   print $class->sprint() . "\n";
}

# ===========================================================================
# Text::SimpleVcard - a package to manage a single vCard
# ===========================================================================
package Text::SimpleVcard;

use warnings;
use strict;

=head1 NAME

Text::SimpleVcard - a package to manage a single vCard

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

simplevCard - This package provides an API to reading a single vCard. A vCard is an
electronic business card. You will find that many applications (KDE Address book,
Apple Address book, MS Outlook, Evolution, etc.) use and can export and import vCards.

This module offers only basic vcard features (folding, ...). Grouping, etc. is not yet
supported. Further enhancements are always welcome.

This module has no other dependencies, it should work with every installation.

   use Text::SimpleVcard;

   open FH, "< std.vcf";        # 'std.vcf' contains a single vcard-entry
   my $vCard = Text::SimpleVcard->new( join( '', <FH>));
   $vCard->print();
   print "FN=" . $vCard->getSimpleValue( 'FN') . "\n";
   print "fullname=" . $vCard->getFullName() . "\n";
   my %h = $vCard->getValuesAsHash( 'TEL', [qw( WORK HOME)]);

   print "phone-numbers are:\n";
   foreach( keys %h) {
      print "Got number $_ ($h{$_})\n";
   }

=head1 FUNCTIONS

=head2 new()

   my $vCard = simpleVcard->new( $dat);

The method will create a C<simpleVcard>object from vcard data (e.g. from
a vCard-File (see example above)). Nested vCards will be ignored.

=cut

sub new {
   my( $class, $data) = @_;
   my $self = {};

   $data =~ s/[\r\n]+ +//gm;            # lines starting with space belong to last line (unfolding)
   my @data = split( /[\r\n]+/, $data);
   my( $fl, $ll) = ( shift( @data), pop( @data));

   if( $fl ne "BEGIN:VCARD" and $ll ne "END:VCARD") {
      warn "vcard should begin with VCARD:BEGIN and end with VCARD:END";
      return;
   }

   my $vCardCnt = 0;
   foreach( @data) {
      $vCardCnt++ if( /^BEGIN:VCARD/);          #
      $vCardCnt-- if( /^END:VCARD/);            # skip nested vcards
      next if( $vCardCnt != 0 or /^END:VCARD/); #
      my $p = Text::SimpleVproperty->new( $_);  # push new property on the array behind the ...
      push( @{ $self->{ $p->{ name}}}, $p);     # ... hash-value of the key with the property-name
   }
   bless( $self, $class);
}

=head2 print()

   $vCard->print();
   $vCard->sprint();

The method will print a C<simpleVcard>-object to stdout or, in case of C<sprint()> to a string

=cut

sub sprint {
   my( $class) = @_;
   my $res = '';

   foreach my $propKey ( keys %$class) {
      foreach my $prop ( @{ $class->{ $propKey}}) {
	 $res .= $prop->sprint() . "\n";
      }
   }
   chomp( $res);
   return $res;
}

sub print {
   my( $class) = @_;

   print $class->sprint() . "\n";
}

=head2 getSimpleValue()

   $vCard->getSimpleValue( $prop);
   $vCard->getSimpleValue( $prop, $n);

The method will fetch the first (or, if an index is provided, the n'th) value
of the specified property.

=cut

sub getSimpleValue {
   my( $class, $prop, $ndx) = @_;

   $ndx = 0 if( !defined ( $ndx));
   my $aryRef = $class->{ uc( $prop)} or return undef;
   my $valRef = ${ @$aryRef}[ $ndx] or return undef;
   return $valRef->{ val};
}

=head2 getFullName()

   $vCard->getFullName();

The method will fetch the value of the property C<FN>, and get rid off
any backslashes found in that value

=cut

sub getFullName {
   my( $class) = @_;

   ( my $fn = $class->getSimpleValue( 'FN')) =~ s/\\//g;
   return $fn;
}

=head2 getValuesAsHash()

   $vCard->getValuesAsHash( 'TEL', [qw( WORK HOME)]]);

The method will return a hash returning the values of the provided property.
The value will contain a CSV-list of the matching types. if no types are provided,
it will return all types found.

=cut

sub getValuesAsHash {
   my( $class, $props, $types) = @_;
   my %res = ();                                        # key=prop-value (e.g. '(07071) 82479')

   foreach my $prop ( @{ $class->{ $props}}) {          # e.g all entries with name='TEL'
      my @types = $types ? @$types : @{ $prop->{ types}};# take all types, if none required

      foreach my $type ( @types) {			# loop over all requested types
	 if( $prop->hasType( uc( $type))) {
	    push( @{ $res{ $prop->{ val}}}, $type);     # push entry in val-part of 'res'
	 }
      }
   }

   foreach ( keys %res) {                       # replace arrays with CSV-value (string)
      my $str = "";

      foreach ( @{ $res{ $_}}) {
	 $str .= "$_,";
      }
      chop( $str);
      $res{ $_} = $str;
   }
   return %res;
}


=head1 AUTHOR

Michael Tomuschat, C<< <michael.tomuschat at t-online.de> >>

=head1 SEE ALSO

Text::SimpleAdrbook - A module that can read several C<vCard>-files

=head1 BUGS

Please report any bugs or feature requests to C<bug-text-simplevcard at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Text-SimpleVcard>. I will 
be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Text::SimpleVcard


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Text-SimpleVcard>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Text-SimpleVcard>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Text-SimpleVcard>

=item * Search CPAN

L<http://search.cpan.org/dist/Text-SimpleVcard>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Michael Tomuschat, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Text::SimpleVcard
