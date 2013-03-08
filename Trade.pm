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
    my ($class, $date, $shares, $price, $charge, $symbol, $sharePrice) = @_;
    
    $self = { date => $date, shares => $shares, price =>$price, charge => $charge, symbol => $symbol,
	  sharePrice => $sharePrice, block => {}};

    bless $self, $class;
}

#combines trade into this trade, does not update TradesList
sub combine
{
    my($self, $other) = @_;

    if ($self->{'date'} != $other->{'date'} || $self->{'symbol'} ne $other->{'symbol'} || $self->{'sharePrice'} != 
	$other->{'sharePrice'} || $self->type ne $other->type || ($self->{'charge'} != 0 && $other->{'charge'} != 0))
    {
	return 0; #unable to combine
    }

    $self->{'shares'} += $other->{'shares'};
    $self->{'charge'} += $other->{'charge'};
    $self->{'price'} += $other->{'price'};

    return 1; #combined successfully
}

#tries to match similar trades in the same block
sub match
{
    my ($self, $other) = @_;
 
    #matches if dates are the same, symbols are the same, type is the same and both of the items have not been charged commission
    #note that prices don't need to be the same to be considered within the same block
    if ($self->{'date'} != $other->{'date'} || $self->{'symbol'} ne $other->{'symbol'} || $self->type ne $other->type || 
       ($self->{'charge'} != 0 && $other->{'charge'} != 0))
    {
	return 0; #unable to match
    }

    #market this to be part of the block of the other. remember, block
    # is a reference
    $self->{'block'} = $other->{'block'};


    return 1;
}

sub toString
{
    my ($self) = @_;

    &main::convertDaysToText($self->{'date'})."\t".$self->{'symbol'}."\t".$self->type."\t".$self->{'shares'}.
	"\t".$self->{'price'}."\t".$self->{'charge'}."\t".$self->{'sharePrice'}."\t".$self->printWash."\n";
}


1;
