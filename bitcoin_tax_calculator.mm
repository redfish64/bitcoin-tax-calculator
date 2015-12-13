<map version="1.0.1">
<!-- To view this file, download free mind mapping software FreeMind from http://freemind.sourceforge.net -->
<node CREATED="1449369607769" ID="ID_568971453" MODIFIED="1449369627570" TEXT="ledger based cryptocurrency tax calculator">
<node CREATED="1449309617743" ID="ID_165769231" MODIFIED="1449311270063" POSITION="right" TEXT="Transactions">
<node CREATED="1449311270031" ID="ID_926862451" MODIFIED="1449311276756" TEXT="Trades, Buys, Sells">
<node CREATED="1449309627247" ID="ID_1220369509" MODIFIED="1449309636187" TEXT="account types">
<node CREATED="1449309637175" ID="ID_655506500" MODIFIED="1449309638467" TEXT="Assets"/>
<node CREATED="1449309638879" ID="ID_1541366106" MODIFIED="1449309640162" TEXT="Expenses"/>
<node CREATED="1449309640751" ID="ID_1286914348" MODIFIED="1449309642003" TEXT="Income"/>
</node>
<node CREATED="1449309642919" ID="ID_1554474561" MODIFIED="1449309651131" TEXT="Sides">
<node CREATED="1449309652175" ID="ID_1616990859" MODIFIED="1449309656867" TEXT="Positive (buy)"/>
<node CREATED="1449309657175" ID="ID_1214863832" MODIFIED="1449309660675" TEXT="Negative (sell)"/>
</node>
<node CREATED="1449310337663" ID="ID_1754668722" MODIFIED="1449310340571" TEXT="error">
<node CREATED="1449310341775" ID="ID_1227796837" MODIFIED="1449310354515" TEXT="To make things simple, we limit to two currencies only"/>
<node CREATED="1449310608007" ID="ID_1178797898" MODIFIED="1449310618836" TEXT="Expenses must be in base currency, or currency of traded items"/>
</node>
<node CREATED="1449310990007" ID="ID_483256145" MODIFIED="1449310996803" TEXT="@ markers are ignored">
<node CREATED="1449310998479" ID="ID_1463095317" MODIFIED="1449311050387" TEXT="This is too confusing as to what it means in a trade. Why would you have an @ $ &lt;x&gt; marker anyway for a trade between two cryptocurrencies? Why would ever know the price of them? "/>
</node>
<node CREATED="1449309695328" ID="ID_1350316264" MODIFIED="1449310551739" TEXT="account line value">
<node CREATED="1449309751615" ID="ID_610153606" MODIFIED="1449310832155" TEXT="Each side will end up with the same value"/>
<node CREATED="1449310450456" ID="ID_1710428103" MODIFIED="1449310769267" TEXT="Ways of deducing price">
<node CREATED="1449310647455" ID="ID_765420373" MODIFIED="1449310648939" TEXT="Assets">
<node CREATED="1449310457528" ID="ID_890605553" MODIFIED="1449310459563" TEXT="base currency">
<node CREATED="1449310460744" ID="ID_1315690012" MODIFIED="1449310560795" TEXT="always itself"/>
</node>
<node CREATED="1449310463752" ID="ID_412498104" MODIFIED="1449310564763" TEXT="other currency">
<node CREATED="1449310580664" ID="ID_1807245611" MODIFIED="1449310585971" TEXT="market price"/>
</node>
<node CREATED="1449310771983" ID="ID_25789293" MODIFIED="1449310932011" TEXT="* If other side is base currency, use it"/>
<node CREATED="1449310799424" ID="ID_628700018" MODIFIED="1449310953867" TEXT="* If market price for both sides, then average them"/>
</node>
<node CREATED="1449310734119" ID="ID_686599602" MODIFIED="1449310735755" TEXT="Expenses">
<node CREATED="1449310747752" ID="ID_634767927" MODIFIED="1449310751059" TEXT="base currency">
<node CREATED="1449311129751" ID="ID_1775287971" MODIFIED="1449311131931" TEXT="always itself"/>
</node>
<node CREATED="1449310580664" ID="ID_1922964676" MODIFIED="1449311146923" TEXT="otherwise calculated based on asset value"/>
</node>
</node>
</node>
<node CREATED="1449309665231" ID="ID_1073901662" MODIFIED="1449310007841" TEXT="Expenses">
<node CREATED="1449310124383" ID="ID_1861630027" MODIFIED="1449310250109">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      Expenses are assigned by currency type
    </p>
    <p>
      
    </p>
    <p>
      So if BTC is on positive side, then expenses go over there
    </p>
  </body>
</html></richcontent>
</node>
</node>
<node CREATED="1449309982575" ID="ID_1098180530" MODIFIED="1449309990827" TEXT="plan">
<node CREATED="1449310026127" ID="ID_1139810438" MODIFIED="1449310039003" TEXT="Split Transaction into Buy for positive side, and sell for negative side"/>
<node CREATED="1449310069303" ID="ID_192446101" MODIFIED="1449310081180" TEXT="For buy side">
<node CREATED="1449310082527" ID="ID_960693364" MODIFIED="1449311253204" TEXT="Create buy, cost basis is trade value plus assigned expenses"/>
</node>
<node CREATED="1449310101608" ID="ID_974715195" MODIFIED="1449310105691" TEXT="For sell side">
<node CREATED="1449310107927" ID="ID_384928794" MODIFIED="1449311239547" TEXT="Create sell, proceeds uses trade value minus assigned expenses"/>
</node>
</node>
<node CREATED="1449311278303" ID="ID_1371787324" MODIFIED="1449311281571" TEXT="Buy/Sell">
<node CREATED="1449311282936" ID="ID_1623805973" MODIFIED="1449311337773">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      Same as trade, but base currency side is ignored (you are basically buying dollars with dollars so result is zero)
    </p>
  </body>
</html></richcontent>
</node>
<node CREATED="1449311353448" ID="ID_1360680275" MODIFIED="1449311367443" TEXT="Expenses for base currency side get moved to other side"/>
</node>
<node CREATED="1449311684335" ID="ID_311553504" MODIFIED="1449311685523" TEXT="Trade">
<node CREATED="1449311686895" ID="ID_560852062" MODIFIED="1449311694459" TEXT="Creates a buy and a sell"/>
</node>
</node>
<node CREATED="1449311374815" ID="ID_563054478" MODIFIED="1449311377043" TEXT="Income">
<node CREATED="1449311378567" ID="ID_826923428" MODIFIED="1449311419643" TEXT="Price">
<node CREATED="1449311420952" ID="ID_372119193" MODIFIED="1449311423572" TEXT="determined by">
<node CREATED="1449311424752" ID="ID_1664094700" MODIFIED="1449311432459" TEXT="@ $&lt;price&gt; if available"/>
<node CREATED="1449311432759" ID="ID_183007874" MODIFIED="1449311440331" TEXT="market price"/>
</node>
</node>
<node CREATED="1449311444255" ID="ID_1642161850" MODIFIED="1449311484452" TEXT="plan">
<node CREATED="1449311485783" ID="ID_312322308" MODIFIED="1449311497740" TEXT="Create buy for price of shares"/>
<node CREATED="1449311498735" ID="ID_309737517" MODIFIED="1449311594707" TEXT="Create IRS output item for income"/>
<node CREATED="1449311595224" ID="ID_1912102226" MODIFIED="1449311643987" TEXT="Expenses are used as cost basis for IRS output item"/>
</node>
</node>
</node>
<node CREATED="1449317626477" ID="ID_237632819" MODIFIED="1449317737710" POSITION="right" TEXT="Buys/Sells">
<font NAME="SansSerif" SIZE="12"/>
<node CREATED="1449317639284" ID="ID_906119566" MODIFIED="1449317642593" TEXT="Input into wash.pl"/>
<node CREATED="1449317693597" ID="ID_1825036912" MODIFIED="1449317756616" TEXT="contains">
<node CREATED="1449317704284" ID="ID_476006773" MODIFIED="1449317705344" TEXT="date"/>
<node CREATED="1449317705972" ID="ID_769052709" MODIFIED="1449317709496" TEXT="shares"/>
<node CREATED="1449317709988" ID="ID_131088728" MODIFIED="1449317712592" TEXT="symbol"/>
<node CREATED="1449317713116" ID="ID_259238412" MODIFIED="1449317713976" TEXT="price"/>
</node>
</node>
<node CREATED="1449311659319" ID="ID_692572390" MODIFIED="1449311661764" POSITION="right" TEXT="plan">
<node CREATED="1449311663232" ID="ID_1356082333" MODIFIED="1449311713427" TEXT="Read ledger files into Buys, Sells, and IRS output items"/>
<node CREATED="1449311714447" ID="ID_354189067" MODIFIED="1449311733523" TEXT="run wash.pl stuff against Buys and Sells"/>
<node CREATED="1449311733895" ID="ID_706823138" MODIFIED="1449311740115" TEXT="Add our IRS output items for income"/>
<node CREATED="1449311740447" ID="ID_1383772840" MODIFIED="1449311755147" TEXT="print out IRS friendly format"/>
<node CREATED="1449311755639" ID="ID_1978520413" MODIFIED="1449311772675" TEXT="print out debug format (which we already created), maybe formatted like ledger???"/>
</node>
<node CREATED="1449369918460" ID="ID_829394826" MODIFIED="1449369918460" POSITION="right" TEXT="">
<node CREATED="1449199940592" ID="ID_1144242550" MODIFIED="1449199944852" TEXT="taxes">
<node CREATED="1449199948704" ID="ID_1004222364" MODIFIED="1449200018822">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      Any currency trade between one currency and another is a taxable event.
    </p>
    <p>
      
    </p>
    <p>
      We find all these currency trades and turn them into &quot;lots&quot;, and report them with normal lot reporting including wash sales
    </p>
  </body>
</html></richcontent>
</node>
<node CREATED="1449200020361" ID="ID_1863911765" MODIFIED="1449200058772" TEXT="Any transfer in/out of Assets is either a fee or some sort of income">
<node CREATED="1449200072608" ID="ID_977469982" MODIFIED="1449200091116" TEXT="We don&apos;t report fees but we subtract them from the lots in a FIFO"/>
<node CREATED="1449200091552" ID="ID_1282272844" MODIFIED="1449200109476" TEXT="We report income using current value of income"/>
</node>
</node>
</node>
<node CREATED="1449659835726" ID="ID_527848386" MODIFIED="1449659837169" POSITION="right" TEXT="plan2">
<node CREATED="1449659838948" ID="ID_1796520925" MODIFIED="1449659856816" TEXT="we convert everything into the wash format, this means adding transfers to wash"/>
<node CREATED="1449659857301" ID="ID_1827757689" MODIFIED="1449659902376">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      After assigning buys to sells, etc. make sure when we total everything up, we get the right balance
    </p>
  </body>
</html>
</richcontent>
</node>
<node CREATED="1449659903325" ID="ID_466455675" MODIFIED="1449659943762" TEXT="Then we make sure that the unassigned buys + transfers equals balance"/>
</node>
<node CREATED="1449704070921" ID="ID_1350184911" MODIFIED="1449704072597" POSITION="right" TEXT="plan3">
<node CREATED="1449704075136" ID="ID_316363856" MODIFIED="1449704082284" TEXT="Account types">
<node CREATED="1449704083376" ID="ID_1283694030" MODIFIED="1449704572887" TEXT="Assets">
<node CREATED="1449704574993" ID="ID_8753814" MODIFIED="1449704583508" TEXT="Things we own"/>
<node CREATED="1449704675929" ID="ID_1041020649" MODIFIED="1449704677701" TEXT="Restrictions">
<node CREATED="1449704679025" ID="ID_1052525172" MODIFIED="1449704695925" TEXT="Only two currencies allowed">
<node CREATED="1449704744482" ID="ID_114930603" MODIFIED="1449704784442">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      Rationale: We could technically support more than 2 but it makes it more complex, because we'd have to get the fair market value of each, and adjust it for the total bought.
    </p>
  </body>
</html>
</richcontent>
</node>
</node>
</node>
</node>
<node CREATED="1449704084872" ID="ID_1602792321" MODIFIED="1449704598039" TEXT="Income">
<node CREATED="1449704601584" ID="ID_1694802152" MODIFIED="1449704608276" TEXT="Taxable income"/>
<node CREATED="1449704663744" ID="ID_797421972" MODIFIED="1449704665869" TEXT="Restrictions">
<node CREATED="1449704208761" ID="ID_22145562" MODIFIED="1449704843292" TEXT="Assets must be + only"/>
<node CREATED="1449704208761" ID="ID_343133123" MODIFIED="1449704838621" TEXT="Assets must have only one currency"/>
</node>
</node>
<node CREATED="1449704086576" ID="ID_1965645215" MODIFIED="1449704088300" TEXT="Expenses">
<node CREATED="1449704285497" ID="ID_1191009642" MODIFIED="1449704303462">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      Ignore because
    </p>
  </body>
</html>
</richcontent>
<node CREATED="1449704304896" ID="ID_912591547" MODIFIED="1449704377014">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      For regular asset trades, expenses are already subtracted from the received amount and added to the spent amount
    </p>
  </body>
</html>
</richcontent>
</node>
<node CREATED="1449704436193" ID="ID_102530921" MODIFIED="1449704453637" TEXT="For income, the amount we received already has expenses subtracted"/>
<node CREATED="1449704457810" ID="ID_1149330887" MODIFIED="1449704487468" TEXT="ie. expenses are already removed. Think of going to a restaurant with hidden VAT tax. You don&apos;t see it, it doesn&apos;t effect you. Same here"/>
</node>
</node>
<node CREATED="1449704088897" ID="ID_1193906935" MODIFIED="1449704096636" TEXT="Unknown">
<node CREATED="1449704490680" ID="ID_710104680" MODIFIED="1449704495084" TEXT="Error if found"/>
</node>
</node>
<node CREATED="1449704924392" ID="ID_1819787136" MODIFIED="1449704933916" TEXT="Total everything into these four accounts">
<node CREATED="1449704937624" ID="ID_248994247" MODIFIED="1449704943645" TEXT="Each account contains">
<node CREATED="1449704944800" ID="ID_1753328" MODIFIED="1449704978908" TEXT="Currency to Amount"/>
</node>
</node>
<node CREATED="1449705121800" ID="ID_1386813312" MODIFIED="1449705142404" TEXT="Transactions">
<node CREATED="1449705143488" ID="ID_1512151616" MODIFIED="1449705146172" TEXT="transfer">
<node CREATED="1449705154456" ID="ID_1025215357" MODIFIED="1449716861109">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      Internal transfer with fees or random expense
    </p>
  </body>
</html>
</richcontent>
<node CREATED="1449705160384" ID="ID_1130411160" MODIFIED="1449716822413">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      ignored for tax but we have to &quot;sell&quot; it off anyway.
    </p>
    <p>
      
    </p>
    <p>
      In other words we need to take it from a buy lot
    </p>
  </body>
</html>
</richcontent>
</node>
</node>
<node CREATED="1449716863624" ID="ID_1782277550" MODIFIED="1449716874331" TEXT="Convert to">
<node CREATED="1449716877095" ID="ID_231015350" MODIFIED="1449716886507" TEXT="Unreported Sell"/>
</node>
</node>
<node CREATED="1449705148857" ID="ID_1945615022" MODIFIED="1449705150308" TEXT="income">
<node CREATED="1449704157305" ID="ID_273753604" MODIFIED="1449704162116" TEXT="Convert to">
<node CREATED="1449704163249" ID="ID_1494185922" MODIFIED="1449704280865">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      Buy for $0 or invoke Asset logic assuming sell side is zero
    </p>
  </body>
</html></richcontent>
</node>
<node CREATED="1449704169240" ID="ID_735525978" MODIFIED="1449704182853" TEXT="Sell for current market value"/>
<node CREATED="1449704183641" ID="ID_462967178" MODIFIED="1449704190445" TEXT="Buy for current market value"/>
</node>
</node>
<node CREATED="1449705150696" ID="ID_352556699" MODIFIED="1449705151756" TEXT="trade">
<node CREATED="1449704572881" ID="ID_164550394" MODIFIED="1449704593315" TEXT="Plan">
<node CREATED="1449704108704" ID="ID_462998287" MODIFIED="1449704113268" TEXT="+ == Buy"/>
<node CREATED="1449704113632" ID="ID_870687886" MODIFIED="1449704116860" TEXT="- == Sell"/>
<node CREATED="1449704126409" ID="ID_1707577342" MODIFIED="1449704135084" TEXT="Ignore base currency buy/sells"/>
<node CREATED="1449704135520" ID="ID_1053883674" MODIFIED="1449704150636" TEXT="Use base currency buy/sells to calculate value of other side if exists"/>
</node>
</node>
</node>
<node CREATED="1449704984777" ID="ID_645233873" MODIFIED="1449704991620" TEXT="Check restrictions"/>
<node CREATED="1449704993736" ID="ID_1385710032" MODIFIED="1449705007149" TEXT="Create buys/sells"/>
<node CREATED="1449705007768" ID="ID_1639930209" MODIFIED="1449705017468" TEXT="Compute taxes"/>
<node CREATED="1449705017777" ID="ID_576645981" MODIFIED="1449705022492" TEXT="Print results"/>
</node>
<node CREATED="1449828475959" ID="ID_1245465067" MODIFIED="1449828480155" POSITION="right" TEXT="bitcoin.tax">
<node CREATED="1449828481200" ID="ID_964849450" MODIFIED="1449828488907" TEXT="Doesn&apos;t allow import before 2013"/>
<node CREATED="1449828498623" ID="ID_1335340514" MODIFIED="1449828500784" TEXT="Can&apos;t use">
<font BOLD="true" NAME="SansSerif" SIZE="12"/>
</node>
</node>
<node CREATED="1449828501495" ID="ID_1480280694" MODIFIED="1449828509220" POSITION="right" TEXT="plan4">
<node CREATED="1449828511903" ID="ID_1003948804" MODIFIED="1449828517451" TEXT="There are about 700 lines"/>
<node CREATED="1449828518663" ID="ID_852422616" MODIFIED="1449829060589">
<richcontent TYPE="NODE"><html>
  <head>
    
  </head>
  <body>
    <p>
      To report a wash, we just need to mark 'W' on the 8949 form and give the adjustment
    </p>
    <p>
      
    </p>
    <p>
      So it doesn't matter on what days the wash occurred. Therefore, it may be possible to combine washes
    </p>
  </body>
</html>
</richcontent>
</node>
<node CREATED="1449835435790" ID="ID_69120174" MODIFIED="1449835445801" TEXT="Good news everybody! wash sales may not apply to bitcoin">
<node CREATED="1449835514695" ID="ID_396883019" MODIFIED="1449835594593" TEXT="https://www.reddit.com/r/Bitcoin/comments/2qar39/i_am_a_tax_attorney_here_are_my_answers_to_common/&#xa;&#xa;#9 Do the wash sale rules apply to bitcoin?&#xa;&#xa;Probably not. The wash sale rules under Section 1091 apply only to &quot;shares of stock or securities.&quot; Therefore, they do not apply to bitcoins unless bitcoins (and virtual currencies in general) qualify as &quot;shares of stock or securities.&quot; This qualification would seem highly unlikely. There&apos;s just really no argument that bitcoins are &quot;shares of stock or securities.&quot; The definition for these terms (taken from Section 1236, for example) is &quot;any share of stock in any corporation, certificate of stock or interest in any corporation, note, bond, debenture, or evidence of indebtedness, or any evidence of an interest in or right to subscribe to or purchase any of the foregoing.&quot; Bitcoins would not appear to meet this definition.&#xa;&#xa;So, as it&apos;s currently written, it does not look like Section 1091 applies to bitcoins and other virtual currencies. That could change in the future of course, but for the moment it seems to be the case.&#xa;&#xa;"/>
<node CREATED="1449835551206" ID="ID_1394125861" MODIFIED="1449835551206" TEXT=""/>
</node>
</node>
</node>
</map>
