#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";

@files = <rtf*.txt>;

$timestampformat = "^../../20.. (..:..:..\....)";

my $showcount=15;
open (OUTFILE, ">TransactionMatcher.out");
my %transactionmap ;
my %errorlist ;
my $errorcount=0;
my @startlist ;
my @interesting;

#RPOOL STUFFmy %poolmap;
my %poolmap;
my %pendinglist ;

print OUTFILE "Parsed File list:\n";
print "Parsing:\n";
#Find all the Call sessions
my $firstline = "";
my $lastline = "";
foreach $file (@files) {
  print "    $file\n";
  print OUTFILE "  $file\n";
  open (MYFILE, $file);
     while (<MYFILE>) {
       if($firstline == ""){
         $firstline = $_;
       }
     #Allocation 11/21/2016 10:54:03.310   4968        6664 sip_stack               Debug        00001A08   INFO   - TRANSACTION  - TransactionMgrCreateTransaction - transaction created: 0x1B9E4CF0
     if(/$timestampformat.*TransactionMgrCreateTransaction - transaction created: (.*?)($|\r|\n)/){
       #print "$2\n";
       my $timestamp=$1;
       my $id=$2;
       if ( not exists $transactionmap{$id} ) {
        #  print "Adding $2\n";
          $transactionmap{$id}=$timestamp;
       } else {
         print "$id is already in map\n";
       }

     }
     #TransactionDestruct - Transaction 0x1B9E4CF0: was destructed
     elsif(/$timestampformat.*TransactionDestruct - Transaction (.*?): was destructed/){
       my $id=$2;
       if ( exists $transactionmap{$id} ) {
          #print "Removing $id\n";
          delete $transactionmap{$id};
       } else {
         print "Unable to find $id in map\n";

       }
     }
     #11/21/2016 10:55:16.677   4968        6664 sip_stack               Error        00001A08   ERROR  - TRANSACTION  - RvSipTransactionMake - Transaction 0x1B90A470: Failed to parse to header - bad syntax (rv=-3000)
     #elsif(/$timestampformat .*ERROR  - TRANSACTION.*Transaction (.*):(.*)($|\r|\n)/){
     #11/29/2016 14:40:52.414   2616        6580 sip_stack               Error        000019B4   ERROR  - TRANSACTION  - TransactionMgrCreateTransaction - Failed to insert new transaction to list (rv=-2)
     elsif(/$timestampformat .*ERROR  - TRANSACTION  - TransactionMgrCreateTransaction -(.*)($|\r|\n)/){
       my $tmp="$1 - $2\n";
       $errorlist{$errorcount}= $errorlist{$2}.$tmp;
       $errorcount=$errorcount+1;
     }

     elsif(/$timestampformat .* gclib                           <:::: (gc_Start)/){
       #print("RESTART Detected\n");
       my $timestamp=$1;
        push @startlist, $2." @ ".$timestamp."\n" ;

     }

     #12/02/2016 11:00:07.862  26996        7320 sip_stack               Debug        00001C98   INFO   - STACK        - PrintConfigParamsToLog
     elsif(/$timestampformat .*PrintConfigParamsToLog(.*?)($|\r|\n)/){
        my $tmp="$1 - $2\n";
        #print $tmp;
        push @interesting, $1." - ".$2."\n"; ;

     }

     # RPOOL STUFF
     #11/29/2016 14:39:05.413   2616        6580 sip_stack               Debug        000019B4   DEBUG  - RPOOL        - RPOOL_GetPage - (pool=0x05201588,size=0,*newRpoolElem=0x05950758)=0 (MessagePool)
     if(/$timestampformat.*RPOOL_GetPage - .*newRpoolElem=(.*?)\)=.* \((.*)\)($|\r|\n)/){
       #print "$2\n";
       my $timestamp=$1;
       my $id=$2;
       my $pool=$3;
       if ( not exists $poolmap{$id} ) {
        #  print "Adding $2\n";
          $poolmap{$id}=$timestamp." - ".$pool;
          print AUDITFILE $id." Allocate @ ".$timestamp." - ".$pool."\n";
       } else {
         print "$id is already in map\n";

       }

     }
     #11/29/2016 14:41:06.430   2616        6580 sip_stack               Debug        000019B4   DEBUG  - RPOOL        - RPOOL_FreePage - (pool=0x05201630,element=0x059D28B0) (GeneralPool)
     elsif(/$timestampformat.*RPOOL_FreePage - \(pool=.*,element=(.*?)\) (.*)($|\r|\n)/){
       my $timestamp=$1;
       my $id=$2;
       if ( exists $poolmap{$id} ) {
          #print "Removing $id\n";
          delete $poolmap{$id};
          print AUDITFILE $id." Free @ ".$timestamp." - ".$pool."\n";
          if ( exists $pendinglist{$id} ) {
              delete $pendinglist{$id};
          }
       } else {
         print "Unable to find $id in map\n";

       }
     }
     #11/29/2016 14:41:06.430   2616        6580 sip_stack               Debug        000019B4   DEBUG  - RPOOL        - RPOOL_FreePage - more than 1 user! do not free the page! (pool=0x05201630,element=0x059D28B0) (GeneralPool)
     elsif(/$timestampformat .*RPOOL_FreePage - .* do not free the page! \(pool=.*,element=(.*?)\) \((.*)\)($|\r|\n)/){
       my $timestamp=$1;
       my $id=$2;
       $pendinglist{$id}=$timestamp;
       print AUDITFILE $id." Pending @ ".$timestamp."\n";
     }

     $lastline = $_;
	 }


  close MYFILE;
  }
  print "\n";
  print OUTFILE "\n";
  $timestamp = $1 if $firstline =~ /$timestampformat.*/;
  print OUTFILE "First line parsed:\n".$firstline."\n";
  print  "Timestamp of First line parsed:\n   ".$timestamp."\n";
  $timestamp = $1 if $lastline =~ /$timestampformat.*/;
  print OUTFILE "Last line parsed:\n".$lastline."\n";
  print  "Timestamp of Last line parsed:\n   ".$timestamp."\n";
  print "\n";
  print OUTFILE "\n";
  my $startcount = @startlist;
  if($startcount > 0){
    print OUTFILE $startcount." Restarts detected in log set\n";
    print $startcount." Restarts detected in log set\n";
    my $count=0;
      foreach (@startlist)
      {
        print "   #".$count."  ".$_."\n";
        print OUTFILE $_."\n";
        $count=$count+1;
      }
  } else {
    print OUTFILE "No Restarts detected in log set\n";
    print "No Restarts detected in log set\n";
  }
  #print actinve TransactionDestruct
  if( keys %transactionmap) {
    my $size = keys(%transactionmap) ;
    print "\n".$size." Active Transactions (".$showcount." displayed):\n";
    print OUTFILE "\n".$size." Active Transactions:\n";
    my $count=0;
    foreach my $key (sort keys %transactionmap) {

      if($count<$showcount){
        print "   #".$count."  ".$key." @ ".$transactionmap{$key}."\n";
        $count=$count+1;
      }
      print OUTFILE $key." @ ".$transactionmap{$key}."\n";
    }
  }else {
      print "    No Active Transactions Detected!\n";
      print OUTFILE "No Active Transactions Detected!\n";
  }

#RPOOL STUFFmy
$count=0;
if( keys %poolmap) {
  my $poolcount = keys(%poolmap) ;
  print "\n ".$poolcount." Active Pools (".$showcount." displayed):\n";
  print OUTFILE "\n ".$poolcount." Active Pools:\n";
  foreach my $key (sort keys %poolmap) {
    if($count<$showcount){
      print "   #".$count."  ".$key." @ ".$poolmap{$key}."\n";
      $count=$count+1;
    }
    print OUTFILE $key." @ ".$poolmap{$key}."\n";
  }
}else {
    print "\nNo Active Pools Detected!\n";
    print OUTFILE "\nNo Active Pools Detected!\n";
}
$count=0;
if( keys %pendinglist) {
  print "\nPending List (".$showcount." displayed):\n";
  print OUTFILE "\nPending List:\n";
  foreach my $key (sort keys %pendinglist) {
      if($count<$showcount){
        print "   #".$count."  ".$key." @ ".$pendinglist{$key}."\n";
        $count=$count+1;
      }
    print OUTFILE $key." @ ".$pendinglist{$key}."\n";
#      if( exists $poolmap{$key} ){
#        print("This was left open transaction!!\n");
#      }
  }
}else {
    print "\nNo Pending Frees Detected!\n";
    print OUTFILE "No Pending Frees Detected!\n";
}
#END RPOOL
  if( keys %errorlist) {
    print "\n".$errorcount." Errors Detected (".$showcount." displayed):\n";
    print OUTFILE "\n".$errorcount." Errors Detected:\n";
    for (my $count=0;$count < $errorcount; $count++){
      if($count < $showcount ){
        print "  #".$count." @ ".$errorlist{$count};
      }
      print OUTFILE "  #".$count." @ ".$errorlist{$count};
      #if( exists $transactionmap{$key} ){
      #  print("This was left open transaction!!\n");
      #}
    }
  }else {
      print "    No errors Detected!\n";
      print OUTFILE "No Errors Detected!\n";
  }

  print "\n";
  print OUTFILE "\n";

  my $interestingcount = @interesting;
  if($interestingcount > 0){
    print OUTFILE $interestingcount." \"interesting\" prints detected in log set\n";
    print $interestingcount." \"interesting\" prints detected in log set\n";
      foreach (@interesting)
      {
        #print $_;
        print OUTFILE $_;
      }
  } else {
    print "No \"interesting\" prints detected in log set\n";
    print OUTFILE "No \"interesting\" prints detected in log set\n";
  }
  close OUTFILE;
  print "\n";

   print "Operation COmplete - See Output file for details\n";
   print "\n";
  #exit
