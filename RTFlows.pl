#!/usr/bin/perl

open (OUTFILE, ">flows.txt");

my %ipmmap = ();
my %mmmap = ();
my %iptmap = ();
my %calllist = ();
my %devhtonamemap = ();
my %nametodevhmap = ();
my @eventList = ();
my $evtcount=0;

#Sip Call info 
my %callidmap;
my $inblock = 0;
my $block = "";
my $callid = "";
my $starttime = "";
my %timestampmap;

# Sharon sigal maps
my %callidtosig;
my %currentsigtocallid;
my %currentsigtoshar;
my %currentshartosig;
my %callidtoshar;
my %sigmap;
my %sharmap;

my %linedevtoipm;
my %linedevtoipt;

my %errmap;


$timestampformat = "^\\d\\d/\\d\\d/20\\d\\d (\\d\\d:\\d\\d:\\d\\d\.\\d\\d\\d)";
my $lastts = "";
my $lastdev;

@files = <rtf*.txt>;
print OUTFILE "Parsed File list:\n";
print "Parsing:\n";
#Find all the Call sessions
foreach $file (@files) {
  print "    $file\n";
  print OUTFILE "  $file\n";
  open (MYFILE, $file);
     while (<MYFILE>) {
     #save off the timestamp
		 if(/$timestampformat.*/){
				$lastts=$1;
				}
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
             elsif(/$timestampformat.*- TRANSPORT    - (    Call-ID: (.*))/){
                #01/06/2017 12:27:44.698  13724       12328 sip_stack               Debug        00003028   INFO   - TRANSPORT    -     Call-ID: 75755E4C10000159720B6FB20A949DCC-148373446486384379@10.148.157.204
               $block = $block.$2."\n";
               $callid = $3;
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
        
			#general IPM calls
		 if(/$timestampformat.*(ipmB\d+C\d+) .*(<:::: |::::> | =<>= ipm_|---- |<====)(.*)/){
			my $ts=$1;
			my $ipmdev=$2;
			my $dir=$3;
			my $action=$4;
			my $entry="$ts $ipmdev $dir $action";
			if( not defined $ipmmap{$ipmdev} ){
				$ipmmap{$ipmdev}=$entry;       
			} else {
			   $ipmmap{$ipmdev}=$ipmmap{$ipmdev}."\n".$entry;
			}
			$lastdev=$ipmdev;
		 }
	   #general MM calls
		 elsif(/$timestampformat.*(mmB\d+C\d+) .*(<:::: |::::> )(.*)/){
			my $ts=$1;
			my $mmdev=$2;
			my $dir=$3;
			my $action=$4;
			my $entry="$ts $mmdev $dir $action";
			if( not defined $mmmap{$mmdev} ){
				$mmmap{$mmdev}=$entry;       
			} else {
			   $mmmap{$mmdev}=$mmmap{$mmdev}."\n".$entry;
			}
			$lastdev=$mmdev;
		 }
		#general IPT/GC calls
	    elsif(/$timestampformat.*(iptB\d+T\d+) .*(<:::: |::::> )(.*)/){
			my $ts=$1;
			my $iptdev=$2;
			my $dir=$3;
			my $action=$4;
			my $entry="$ts $iptdev $dir $action";
			if( not defined $iptmap{$iptdev} ){
				$iptmap{$iptdev}=$entry;       
			} else {
			   $iptmap{$iptdev}=$iptmap{$iptdev}."\n".$entry;
			}
			$lastdev=$iptdev;
		 }
        
		#Sigal
        #09/10/2018 19:31:41.656   7224        7440 gc_h3r       SIP_CAPS   DEBG         sip_caps.cpp:2859     !    38 ! >> SIP_Caps::determineCapsMatchResult()
        elsif(/$timestampformat.* SIP_.*?\!.*?(\d+).*?\! (.*)/){
			my $ts=$1;
			my $sigdev=$2;
			my $action=$3;
			my $entry="$ts SIGAL-$sigdev $action";
			if( not defined $sigmap{$sigdev} ){
				$sigmap{$sigdev}=$entry;       
			} else {
			   $sigmap{$sigdev}=$sigmap{$sigdev}."\n".$entry;
			}
		#	$lastdev=$sigdev;
		 }
         #Sharon
        #09/10/2018 19:31:41.656   7224        6412 gc_h3r       SH_DECODER DEBG         decoder.cpp:1286      !   220 ! >> decodeMsg:OnEvent... idx: 220
        elsif(/$timestampformat.* SH_.*?\!.*?(\d+).*?\! (.*)/){
			my $ts=$1;
			my $shardev=$2;
			my $action=$3;
			my $entry="$ts SHARON-$shardev $action";
            if($shardev != 0){
            
			if( not defined $sharmap{$shardev} ){
				$sharmap{$shardev}=$entry;       
			} else {
			   $sharmap{$shardev}=$sharmap{$shardev}."\n".$entry;
			}
		#	$lastdev=$shardev;
            }
		 }
         
         if(/$timestampformat.*(iptB\d+T\d+) .*GC event:(0x.+)h\((.*)\) posted on linedev:(\d+), crn:(0x[\da-f]+)h/){
			my $ts=$1;
			my $iptdev=$2;
		
			my $hexevt=$3;
			my $txtevt=$4;
			my $ldev=$5;
			my $crn=$6;
			my $entry="$ts $iptdev ----- $txtevt($hexevt) ldev=$ldev crn=$crn";
			
			if( not defined $iptmap{$iptdev} ){
				$iptmap{$iptdev}=$entry;       
			} else {
			   $iptmap{$iptdev}=$iptmap{$iptdev}."\n".$entry;
			}

			$lastdev=$iptdev;
		 }
         
         #linedev/ldev
         if(/$timestampformat.*(iptB\d+T\d+) .*(ldev|linedev):(\d+),.*?/){
			my $ts=$1;
			my $iptdev=$2;
			my $ldev=$4;
			
			$linedevtoipt{$ldev} = $iptdev;
            #print $_;
			#print "Mapping: ".$ldev." <-> ".$iptdev."\n";	
		 }
         elsif(/$timestampformat.*(ipmB\d+C\d+) .*(ldev|linedev):(\d+),.*?/){
			my $ts=$1;
			my $ipmdev=$2;
			my $ldev=$4;
			
			$linedevtoipm{$ldev} = $ipmdev;
            #print $_;
			#print "Mapping: ".$ldev." <-> ".$iptdev."\n";	
		 }
         elsif(/$timestampformat.*?(<:::: |::::> | =<>= ipm_|---- |<====)(.*?(ldev|linedev):(\d+),.*)/){
			my $ts=$1;
			my $dir=$2;
            my $ldev=$5;
			my $action=$3;
			
            
            if( defined $linedevtoipt{$ldev} ){
            
                $iptdev=$linedevtoipt{$ldev};
                my $entry="$ts $iptdev $dir $action";
				$iptmap{$iptdev}=$iptmap{$iptdev}."\n".$entry;
			}
			if( defined $linedevtoipm{$ldev} ){
            
                $ipmdev=$linedevtoipm{$ldev};
                my $entry="$ts $ipmdev $dir $action";
				$ipmmap{$ipmdev}=$ipmmap{$ipmdev}."\n".$entry;
			}
		 }
         
		 #any Other Event
		 #iptB1T1   ----- GC event:0x824h(GCEV_OFFERED) posted on linedev:57, crn:0x1h
		 if(/$timestampformat.*(iptB\d+T\d+) .*GC event:(0x.+)h\((.*)\) posted on linedev:(\d+), crn:(0x[\da-f]+)h/){
			my $ts=$1;
			my $iptdev=$2;
		
			my $hexevt=$3;
			my $txtevt=$4;
			my $ldev=$5;
			my $crn=$6;
			my $entry="$ts $iptdev ----- $txtevt($hexevt) ldev=$ldev crn=$crn";
			
			if( not defined $iptmap{$iptdev} ){
				$iptmap{$iptdev}=$entry;       
			} else {
			   $iptmap{$iptdev}=$iptmap{$iptdev}."\n".$entry;
			}

			$lastdev=$iptdev;
		 }
         
		 #10/02/2017 22:32:25.250  32484  4049021808 gc                      INFO         gclib                           ----- gc_GetMetaEvent() returns:0 on ldev:0, crn:0x0h with event:0xc001h(NON-GLOBALCALL EVENT)
		 #10/02/2017 22:35:59.506  32484  4049021808 gc                      INFO         gclib                           ----- gc_GetMetaEvent() returns:0 on ldev:57, crn:0x8000001h with event:0x824h(GCEV_OFFERED)
		if(/$timestampformat.*gc_GetMetaEvent\(\).*event:(0x.+h)\((.+)\)/){
			my $ts=$1;
			my $hexevt=$2;
			my $txtevt=$3;
			if ($txtevt eq "NON-GLOBALCALL EVENT"){
				$txtevt=evt_hex_to_txt($hexevt);
			}
			my $entry="$ts -EVENT-  $txtevt  ($hexevt)";
			$eventList[$evtcount]=$entry;       
			$evtcount=$evtcount+1;
		 }
         
         #09/10/2018 19:31:37.309   7224        7440 gc_h3r       SIP_IE     DEBG         sip_info_elemen:7871  !    38 ! SIP_IE::GetCallIDHdrFromRVMsg Getting CallID Hdr value (7c0b2d8-0-13c4-65014-4f4a11-7e208e5-4f4a11).
        if(/$timestampformat.* \!.*?(\d+).*?\! SIP_IE::GetCallIDHdrFromRVMsg Getting CallID Hdr value \((.*?)\)/){
			my $ts=$1;
			my $sigid=$2;
			my $callid=$3;
            #print "Mapping: ".$sigid." <-> ".$callid."|\n";
			$callidtosig{$callid}=$sigid;       
            $currentsigtocallid{$sigid}=$callid;
	          
		 }
         #09/10/2018 19:31:37.309   7224        7440 gc_h3r       SIP_SI..NC DEBG         sip_encoder.cpp:1078  !    38 ! SIP_ENCODER::Encode Msg: Sigal [38] -> Sharon [220] : EvtType_SIPMsgInfo (112)
        if(/$timestampformat.* \!.*?(\d+).*?\!.*?Msg: Sigal \[(\d+)\] -> Sharon \[(\d+)\]/){
			my $ts=$1;
			my $sigid=$2;
            my $sigid2=$3;
			my $sharid=$4;
         #   print "Mapping: sig[".$sigid."] <-> Sharon [".$sharid."]\n";			
            $currentsigtoshar{$sigid}=$sharid;
            $currentshartosig{$sharid}=$sigid;
	        if(defined $currentsigtocallid{$sigid} ){
                $callid=$currentsigtocallid{$sigid};
				$callidtoshar{$callid}=$sharid;
             #   print "Mapping: callid[".$callid."] <-> Sharon [".$sharid."]\n";	
			}  
		 } 

         
   }
   close (MYFILE);
}

print "   Parsing Complete!\n";
print "   Last Timestamp processed = $lastts\n";
print OUTFILE "\nLast Timestamp processed = $lastts\n";
print   "\n\n==================================\n";
my $count= keys %ipmmap;
print  "    $count IPM Flows detected\n";
print   OUTFILE "\n\n==================================\n";
print   OUTFILE "ipm Flows (count = $count)\n";
print   OUTFILE "==================================\n";
foreach my $key (sort keys %ipmmap) {
     print  OUTFILE "{\n";
	 
     print   OUTFILE "\"$key\" : \"\n$ipmmap{$key}\"\n";
     print  OUTFILE "}\n";
  }
 $count= keys %mmmap;
print  "    $count MM  Flows detected\n";
print   OUTFILE "\n\n==================================\n";
print   OUTFILE "MM Flows (count = $count)\n";
print   OUTFILE "==================================\n";
foreach my $key (sort keys %mmmap) {
     print  OUTFILE "{\n";
     print   OUTFILE "\"$key\" : \"\n$mmmap{$key}\"\n";
     print  OUTFILE "}\n";
  }
$count= keys %iptmap ;
print  "    $count IPT Flows detected\n";
print   OUTFILE "\n\n==================================\n";
print   OUTFILE "IPT Flows (count = $count)\n";
print   OUTFILE "==================================\n";
foreach my $key (sort keys %iptmap) {
     print  OUTFILE "{\n";
     print   OUTFILE "\"$key\" : \"\n$iptmap{$key}\"\n";
     print  OUTFILE "}\n";
  }
$count= keys %sigmap ;
print  "    $count Sigal Flows detected\n";
print   OUTFILE "\n\n==================================\n";
print   OUTFILE "Sigal Flows (count = $count)\n";
print   OUTFILE "==================================\n";
foreach my $key (sort keys %sigmap) {
     print  OUTFILE "{\n";
     print   OUTFILE "\"$key\" : \"\n$sigmap{$key}\"\n";
     print  OUTFILE "}\n";
  }
$count= keys %sharmap ;
print  "    $count Sharon Flows detected\n";
print   OUTFILE "\n\n==================================\n";
print   OUTFILE "Sharon Flows (count = $count)\n";
print   OUTFILE "==================================\n";
foreach my $key (sort keys %sharmap) {
     print  OUTFILE "{\n";
     print   OUTFILE "\"$key\" : \"\n$sharmap{$key}\"\n";
     print  OUTFILE "}\n";
  }

print  "    $evtcount Events detected\n";
print   OUTFILE "\n\n==================================\n";
print   OUTFILE "Events (count = $evtcount)\n";
print   OUTFILE "==================================\n";
my $index=0;
     print  OUTFILE "{\n";
while ($index < $evtcount){
     print   OUTFILE "$eventList[$index]\n";
	 $index=$index+1;
  }
 print  OUTFILE "}\n";
 
  #print Out all the calls
  if( keys %callidmap) {
    my $count = keys(%callidmap) ;
    print "    ".$count." Unique SIP Call-IDs detected\n";
    print OUTFILE $count." Unique Call-IDs detected:\n";
    print OUTFILE "=================================================================================\n";
    foreach my $call (keys %callidmap) {
	  #print $call." @ ".$timestampmap{$call};
	  print OUTFILE "=========================== ".$call." ===========================\n";
      print OUTFILE "    Sigal Object - ".$callidtosig{$call}."\n";
      print OUTFILE "    Sharon Object - ".$callidtoshar{$call}."\n";
      print OUTFILE $callidmap{$call};
	  
    }
  }else {
      print "    No Sip Calls Detected!\n";
      print OUTFILE "No Sip Calls Detected!\n";
  }
  print "=================================================================================\n";
  print OUTFILE "=================================================================================\n";
 
 close OUTFILE; 
################# SUBS #################
sub format_block{
    my ($block) = @_;

    $block =~ s/%3[a|A]/:/g;
    $block =~ s/\\r\\n/\n      /g;
    $block =~ s/\\t/    /g;
    $block =~ s/></>\n       </g;
    $block =~ s/\\\//\\/g;
    $block =~ s/\\\"/\"/g;

    return $block
}

sub get_entry_from_block{
    my ($block) = @_;

    $block =~ s/%3[a|A]/:/g;
    $block =~ s/\\r\\n/\n      /g;
    $block =~ s/\\t/    /g;
    $block =~ s/></>\n       </g;
    $block =~ s/\\\//\\/g;
    $block =~ s/\\\"/\"/g;

    return $block
}

sub evt_hex_to_txt{
	my ($hex) = @_;
	my ($txt) = "NON-GLOBALCALL EVENT" ;
	
	if( $hex eq "0x0h") {($txt) = "NON-GLOBALCALL EVENT" ; }
	#IPM
	elsif( $hex eq "0x9001h") {($txt) = "IPMEV_OPEN" ; }
	elsif( $hex eq "0x9002h") {($txt) = "IPMEV_STARTMEDIA" ; }
	elsif( $hex eq "0x9003h") {($txt) = "IPMEV_STOPPED" ; }
	elsif( $hex eq "0x9013h") {($txt) = "IPMEV_SET_PARM" ; }
	elsif( $hex eq "0x9014h") {($txt) = "IPMEV_GET_PARM" ; }
	elsif( $hex eq "0x901eh") {($txt) = "IPMEV_ERROR" ; }
	elsif( $hex eq "0x902bh") {($txt) = "IPMEV_GENERATEIFRAME" ; }
	elsif( $hex eq "0x982bh") {($txt) = "IPMEV_GENERATEIFRAME_FAIL" ; }
	elsif( $hex eq "0x9017h") {($txt) = "IPMEV_TELEPHONY_EVENT" ; }
	elsif( $hex eq "0x9021h") {($txt) = "IPMEV_MODIFYMEDIA" ; }
	#MM
	elsif( $hex eq "0xa001h") {($txt) = "MMEV_OPEN" ; }
	elsif( $hex eq "0xa002h") {($txt) = "MMEV_PLAY_ACK" ; }
	elsif( $hex eq "0xa003h") {($txt) = "MMEV_RECORD_ACK" ; }
	elsif( $hex eq "0xa004h") {($txt) = "MMEV_STOP_ACK" ; }
	elsif( $hex eq "0xa006h") {($txt) = "MMEV_ENABLEEVENTS" ; }
	elsif( $hex eq "0xa008h") {($txt) = "MMEV_PLAY" ; }
	elsif( $hex eq "0xa009h") {($txt) = "MMEV_RECORD" ; }
	elsif( $hex eq "0xa8ffh") {($txt) = "MMEV_ERROR" ; }
	elsif( $hex eq "0xa802h") {($txt) = "MMEV_PLAY_ACK_FAIL" ; }
	elsif( $hex eq "0xa803h") {($txt) = "MMEV_RECORD_ACK_FAIL" ; }
	elsif( $hex eq "0xa804h") {($txt) = "MMEV_STOP_ACK_FAIL" ; }
	#DM
	elsif( $hex eq "0x9e01h") {($txt) = "DMEV_CONNECT" ; }
	elsif( $hex eq "0x9e02h") {($txt) = "DMEV_CONNECT_FAIL" ; }
	elsif( $hex eq "0x9e03h") {($txt) = "DMEV_DISCONNECT" ; }
	elsif( $hex eq "0x9e04h") {($txt) = "DMEV_DISCONNECT_FAIL" ; }
	elsif( $hex eq "0x9e25h") {($txt) = "DMEV_PORT_CONNECT" ; }
	elsif( $hex eq "0x9e26h") {($txt) = "DMEV_PORT_CONNECT_FAIL" ; }
	elsif( $hex eq "0x9e27h") {($txt) = "DMEV_PORT_DISCONNECT" ; }
	elsif( $hex eq "0x9e28h") {($txt) = "DMEV_PORT_DISCONNECT_FAIL" ; }
	#TDX
	elsif( $hex eq "0x81h") {($txt) = "TDX_PLAY" ; }
	elsif( $hex eq "0x83h") {($txt) = "TDX_GETDIG" ; }
	elsif( $hex eq "0x86h") {($txt) = "TDX_CST" ; }
	
	return $txt;
}