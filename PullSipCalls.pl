#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";

@files = <rtf*.txt>;

$timestampformat = "^(../../20.. ..:..:..\....)";

open (OUTFILE, ">SipCallInfo.out");
open (FLAGGEDOUTFILE, ">SipCallInfo_flagged.out");

my %callidmap;
my $inblock = 0;
my $block = "";
my $callid = "";
my $starttime = "";

my %errorlist ;
my $errorcount=0;

my %timestampmap;

print OUTFILE "Parsed File list:\n";
print "Parsing:\n";
#Find all the Call sessions
foreach $file (@files) {
  print "    $file\n";
  print OUTFILE "  $file\n";
  open (MYFILE, $file);
     while (<MYFILE>) {
     if(/$timestampformat.*- TRANSPORT    - ((-->|<--).*SIP\/2.0.*)/){
		 #Start of message
		 #01/06/2017 12:31:11.403  13724       12328 sip_stack               Debug        00003028   INFO   - TRANSPORT    - --> SIP/2.0 200 OK
		 #or
		 #01/06/2017 12:27:44.698  13724       12328 sip_stack               Debug        00003028   INFO   - TRANSPORT    - <-- INVITE sip:1416554@VHT-Titan.sgroup.gsm1900.org SIP/2.0
	   $inblock=1;
       my $starttime=$1;
	   $starttime=~s/\r//g;
	   $block = "\n".$starttime."  (".$file.")\n".$2."\n";
     }
     elsif(/$timestampformat.*- TRANSPORT    - (    Call-ID:.*)/){
		#01/06/2017 12:27:44.698  13724       12328 sip_stack               Debug        00003028   INFO   - TRANSPORT    -     Call-ID: 75755E4C10000159720B6FB20A949DCC-148373446486384379@10.148.157.204
	   $block = $block.$2."\n";
	   $callid = $2;
	   $callid=~s/\r//g;;
     }
     elsif(/$timestampformat.*- TRANSPORT    - (    [A-Z].*)/){
		#01/06/2017 12:27:44.698  13724       12328 sip_stack               Debug        00003028   INFO   - TRANSPORT    -     Expires: 60
	   $block = $block.$2."\n";         
     }
	 #SDP
	 elsif(/$timestampformat.*- TRANSPORT    - (    [a-z]\=.*)/){
		#01/06/2017 12:27:44.698  13724       12328 sip_stack               Debug        00003028   INFO   - TRANSPORT    -     Expires: 60
	   $block = $block.$2."\n";         
     }
	 elsif (/$timestampformat.*- TRANSPORT    - Transport/ && $inblock == 1){
	    $block=~s/\r//g;
		
		#end of message
		#01/06/2017 12:27:44.698  13724       12328 sip_stack               Debug        00003028   INFO   - TRANSPORT    - 
		if ( not exists $timestampmap{$callid} ) {
		 
         $timestampmap{$callid} = $starttime ;
        }
		
		if ( exists $callidmap{$callid} ) {
          $callidmap{$callid} = $callidmap{$callid}." ".$block ;  
       } else {
         $callidmap{$callid} = $block ;
       }
	   #printf $block;
	   $block = "" ;
	   $inblock = 0 ;
	   $callid = "";
	   $starttime = "";
	   
	 }
	
	#Track Some errors
    elsif(/$timestampformat.*( ERR1         | Error        )(.*)/){ 
		#01/06/2017 13:48:57.688  13724       11164 libipm_ipvsc            ERR1         Resource              ::ReserveResource()-> All available Resource Reservations are in use.
		#01/06/2017 13:48:57.689  13724       11164 libipm_ipvsc            ERR1         ReservationDBase      ::ReserveResource()-> Reservation of Resource 1 failed.
		#01/06/2017 13:48:57.689  13724       12032 libipm_ipvsc            ERR1         CIPVscChannel         ipmB1C338  ---  ::ReserveResource-> Resource Reservation Failed.
		#01/06/2017 13:49:02.796  13724       12328 sip_stack               Error        00003028   ERROR  - CALL         - CallLegLock - Call 0x13A8D560: CallLeg object was destructed
		#01/06/2017 13:49:03.391  13724       12328 sip_stack               Error        00003028   ERROR  - CALL         - CallLegLock - Call 0x13A92F60: CallLeg object was destructed
		
		my $tmp="$1 - $3\n";
		   $errorlist{$errorcount}= $errorlist{$2}.$tmp;
		   $errorcount=$errorcount+1;
		 }
	}
  
	
  close MYFILE;
  }
  print "=================================================================================\n";
  print OUTFILE "=================================================================================\n";
  #print Out all the calls
  if( keys %callidmap) {
    my $count = keys(%callidmap) ;
    print $count." Unique Call-IDs detected:\n";
    print OUTFILE $count." Unique Call-IDs detected:\n";
    foreach my $call (keys %callidmap) {
	  #print $call." @ ".$timestampmap{$call};
	  print OUTFILE "=========================== ".$call." ===========================\n";
      print OUTFILE $callidmap{$call};
	  if($callidmap{$call} =~ / ([4-5]\d\d) /g){
		print FLAGGEDOUTFILE "=========================== ".$call."  ".$1." ===========================\n";
		print FLAGGEDOUTFILE $callidmap{$call};
	  }
    }
  }else {
      print "    No Sip Calls Detected!\n";
      print OUTFILE "No Sip Calls Detected!\n";
  }
  print "=================================================================================\n";
  print OUTFILE "=================================================================================\n";
  
  if( $errorcount > 0) {
    print $errorcount." Errors Detected\n";
    print OUTFILE $errorcount." Errors Detected\n";
    for (my $count=0;$count < $errorcount; $count++){
      print OUTFILE "#".$count." @ ".$errorlist{$count};
    }
  }else {
      print "    No errors Detected!\n";
      print OUTFILE "No Errors Detected!\n";
  }
  close OUTFILE;
  close FLAGGEDOUTFILE;
  
  #exit
