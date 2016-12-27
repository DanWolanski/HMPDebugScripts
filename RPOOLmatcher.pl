#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";

@files = <rtf*.txt>;

$timestampformat = "^../../20.. (..:..:..\....)";

open (OUTFILE, ">RPoolMatcher.out");
open (AUDITFILE, ">RPoolAudit.out");
my %poolmap;
my %pendinglist ;
my %errorlist ;
my $errorcount=0;

print OUTFILE "Parsed File list:\n";
print "Parsing:\n";
#Find all the Call sessions
foreach $file (@files) {
  print "    $file\n";
  print OUTFILE "  $file\n";
  open (MYFILE, $file);
     while (<MYFILE>) {
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
     #11/29/2016 14:37:51.162   2616        6580 sip_stack               Error        000019B4   ERROR  - RA           - RA_Alloc - (raH=0x052FD3D0(Transaction List),ElementPtr=0x056DD0BC)=-2: No more elements are available
     elsif(/$timestampformat .*ERROR  - RA           - RA_Alloc .*:(.*)($|\r|\n)/){
       my $tmp="$1 - $2\n";
       $errorlist{$errorcount}= $errorlist{$2}.$tmp;
       $errorcount=$errorcount+1;
       print AUDITFILE "ERROR  @ ".$timestamp." - ".$2."\n";
     }


	 }


  close MYFILE;
  }
  #print actinve TransactionDestruct
  if( keys %poolmap) {
    my $count = keys(%poolmap) ;
    print "\n ".$count." Active Pools:\n";
    print OUTFILE "\n ".$count." Active Pools:\n";
    foreach my $key (sort keys %poolmap) {
      print "    ";
      print $key." @ ".$poolmap{$key}."\n";
      print OUTFILE $key." @ ".$poolmap{$key}."\n";
    }
  }else {
      print "    No Active Pools Detected!\n";
      print OUTFILE "No Active Pools Detected!\n";
  }

  if( keys %pendinglist) {
    print "\nPending List:\n";
    print OUTFILE "\nPending List:\n";
    foreach my $key (sort keys %pendinglist) {
      print "    ";
      print $key." @ ".$pendinglist{$key}."\n";
      print OUTFILE $key." @ ".$pendinglist{$key}."\n";
#      if( exists $poolmap{$key} ){
#        print("This was left open transaction!!\n");
#      }
    }
  }else {
      print "    No Pending Frees Detected!\n";
      print OUTFILE "No Pending Frees Detected!\n";
  }

  if( keys %errorlist) {
    print "\nErrors:\n";
    print OUTFILE "\nErrors:\n";
    for (my $count=0;$count < $errorcount; $count++){

      print "    ";
      print "#".$count." @ ".$errorlist{$count};
      print OUTFILE "#".$count." @ ".$errorlist{$count}."\n";
      #if( exists $transactionmap{$key} ){
      #  print("This was left open transaction!!\n");
      #}
    }
  }else {
      print "    No errors Detected!\n";
      print OUTFILE "No Errors Detected!\n";
  }
  close OUTFILE;
  close AUDITFILE;

  #exit
