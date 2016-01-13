bitcoin-tax-calculator
======================

Calculates capital gains taxes for ledger style cryptocurrency trades (doesn't compute wash sales, see https://www.reddit.com/r/Bitcoin/comments/2qar39/i_am_a_tax_attorney_here_are_my_answers_to_common/ question 9 ... has this functionality in the code, but disabled for now)

Usage perl ledger_wash.pl -a (assets regexp) -i (income regexp) -e (expenses regexp) -bc (base currency (usually \$ or USD)) \[-accuracy (decimal accuracy, defaults to 20 places)\]  (dat file1) \[dat file2...\]

Reads a ledger style file (see http://www.ledger-cli.org/) and creates a capital gains report using the FIFO method.

This program will look for any transaction where two different currencies are included in a transaction,
and are both designated within accounts you own (ex. USD and BTC, or BTC and ETH). 

It will also look for transactions from an Income account and an Asset account. These are considered
taxable income events and included in the report.

Accounts are split into three categories. Assets, Expenses and Income.

Assets are accounts you own and you wish to calculate capital gains for. Note that you'll probably
 want to include liability accounts in this category, since paying down a CC is really the addition
 to a negative asset (if you pay your credit card with a cryptocurrency, that is)
 
Income are accounts from which you receive an Asset. For example, if you mine bitcoin and you have
    an 'Income:Mining' account.
    
Expenses are accounts where expenses go. When expenses are one or more of the outputs for trades or
    income transactions, they are deducted from the capital gains received. In any other transaction,
    (such as those associated with transferring assets around), they are ignored for reporting,
    but still kept track of, so that funds spent in expenses don't appear as a basis for sells.

(assets regex) : Regex for when an account should be included in Assets (default '^Assets' which means 
   begins with Assets)
   
(income regex) : Same as above, but for Income accounts (default '^Income')

(expenses regex) : Same as above, but for Expenses accounts (default '^Expesnses')

If an account matches two or more of the above, it will be considered an error.

(base currency) : The currency used to calculate the capital gains report in. Usually this will be USD,
   $, or whatever you use for your countries currency.

Transactions will be combined if on the same day, for the same types of currency and are adjacent
in time order.

If a time is present after the date, ex:
```
2015-08-15 11:09:05
  Assets:Kraken     -0.123052 BTC
  Assets:Kraken     25.126 ETH
  Expenses:Fees     0.0000520000 BTC
```

the time will be used to sort transactions. Otherwise, transactions on the same day will be sorted in the
order specified in the file(s).
