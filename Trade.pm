package Trade;

# Copyright 2012 Rareventure, LLC
#
# This file is part of Bitcoin Tax Calculator
# Bitcoin Tax Calculator is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# Bitcoin Tax Calculator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Bitcoin Tax Calculator.  If not, see <http://www.gnu.org/licenses/>.
#
# If you make modifications to this software that you feel
# increases it usefulness for the rest of the community, please
# email the changes, enhancements, bug fixes as well as any and
# all ideas to me. This software is going to be maintained and
# enhanced as deemed necessary by the community.
#
# Tim Engler (engler@gmail.com)

sub new
{
    my ($class, $date, $shares, $price, $symbol, $refs) = @_;

    die unless defined $price;

    die unless ref $price eq 'Math::BigRat';
    die unless ref $shares eq 'Math::BigRat';
    die unless ref $refs eq 'ARRAY';
    
    if($shares < 0)
    {
	die "Why negative? $shares";
    }

    if($price < 0)
    {
	die "Why negative? $price";
    }
    
    $self = { date => $date, shares => $shares, price =>$price, symbol => $symbol,
	  block => {}, refs => $refs};

    bless $self, $class;
}

#combines trade into this trade, does not update TradesList
sub combine
{
    my($self, $other) = @_;

#    print STDERR "Trying to combine $self->{symbol}, $other->{symbol}, ".$self->type.", ".$other->type."\n";
    if ($self->{date} != $other->{date} || $self->{symbol} ne $other->{symbol} || $self->type ne $other->type)
    {
	return 0; #unable to combine
    }

    $self->{shares} += $other->{shares};
    $self->{price} += $other->{price};

    push @{$self->{refs}}, @{$other->{refs}};

    return 1; #combined successfully
}

sub refs_string
{
    my ($t) = @_;

    my %file_to_lines;

    foreach my $ref (@{$t->{refs}})
    {
	push @{$file_to_lines{$ref->{file}}}, $ref->{line};
    }

    return join(" ",map { $_.":".join(",",sort @{$file_to_lines{$_}}) } (sort keys %file_to_lines));
}

sub toString
{
    my ($self) = @_;

    &main::convertDaysToText($self->{date}).
	"\t".$self->{symbol}."\t".$self->type."\t".main::format_amt($self->{shares}).
	"\t".main::format_amt($self->{price}).
	"\t".main::format_amt($self->{price}/$self->{shares}).
	"\t".refs_string($self)."\n";
}


1;
