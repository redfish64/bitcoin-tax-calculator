#########A Sell Trade
package Sell;


# Copyright 2012 Rareventure, LLC
# Copyright 2015,2016 Rareventure, LLC
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

use Trade;

@ISA = qw(Trade);

#indicates where the sell should be reported
use constant {
    RT_NORMAL   => 'RT_NORMAL', #this will show it in the irs reports
    RT_GIFT   => 'RT_GIFT', #this will show it in the gift reports
    RT_UNREPORTED   => 'RT_UNREPORTED' # this will show it nowhere (used for internal transfer fees)
};

sub new
{
    #report_type - 
    my ($class, $date, $shares, $price, $symbol, $refs, $report_type) = @_;
    
    $self = Trade::new($class, $date, $shares, $price, $symbol, $refs);

    $self->{report_type} = $report_type;

    #if($report_type eq RT_GIFT) { print STDERR "DEBUG: IS RT_GIFT!\n"; }

    die unless defined $report_type;
    
    $self->init();

    $self;
}

#initializes a sell
sub init
{
    $self->{buy} = undef; #buy for this sell
}

sub type
{
    "sell";
}

#we call this recursively for related buys and wash sales.
# we alwys go in the order $sell->$buy->$washSell->$washSellBuy...
sub split
{
    my ($self, $trades, $newShares, $washBuyCause, $washBuySplit) = @_;

    my $otherShares = $self->{shares} - $newShares;
    my $newPrice = $self->{price} * $newShares / $self->{shares};
    my $otherPrice = $self->{price} * $otherShares / $self->{shares};

    #create a new buy split off from this one. No charge for this buy, and give it the shares not allocated
    my $splitSell = new Sell($self->{date}, $otherShares, $otherPrice,
			   $self->{symbol}, $self->{refs}, $self->{report_type});

    $self->{shares} = $newShares;
    $self->{price} = $newPrice;

    #insert the new buy right after us
    $trades->insertAfter($splitSell, $self);

    #now split the buy for this sell recursively, naming us and our newly defined split cousin as the cause
    if($self->{buy})
    {
	$self->{buy}->split($trades, $newShares, $self, $splitSell);
    }

    if(defined $washBuySplit)
    {
	if($washBuyCause->{shares} != $newShares)
	{
	    die "wash cause buy has differing shares from newShares $washBuyCause->{shares} != $newShares ";
	}
	
	if($otherShares != $washBuySplit->{shares})
	{
	    die "other shares has differing shares from split wash buy, $otherShares != $washBuySplit->{shares}";
	}

	$washBuySplit->markAsWash($splitSell);
    }
    
    return $splitSell;
}




#returns  the gain or loss based on the buy and the buy date
sub getBuyPrice
{
    my ($self) = @_;
    
    my $buy = $self->{buy};

    return ($buy->getBasis(), $buy->{date});
}

sub getGain
{
    my ($self) = @_;

    my ($buyPrice) = $self->getBuyPrice();
    return $self->{price}- $buyPrice;
}

sub toString
{
    my ($self) = @_;

    $s = Trade::toString($self);

    if($self->{buy}){
	$s .= "    gain is ".main::format_amt($self->getGain())."\n";
    }

    return $s;
}

sub isWash
{
    my ($self) = @_;

    $self->{washBuy};
}

#checks if sell date is more than a year past buy date
sub isLongTerm
{
    my ($self) = @_;

    my $sell_date = main::convertDaysToText($self->{date});

    return $self->{buy}->isLongTermToDate($sell_date);
}
    
sub toWashString
{
    my ($self) = @_;
    
    my $s = "";
    if($self->isWash)
    {
	$s = "wash";
    }

    if($self->{buy} && $self->{buy}->{washSell})
    {
	my $ws = $self->{buy}->{washSell};

	if(length $s != 0)
	{
	    $s .= ", ";
	}

	$s .= "basis offset by ".main::format_amt($ws->getGain())." for wash sale on "
	    .&main::convertDaysToText($ws->{date});
    }

    return $s;
}

1;
