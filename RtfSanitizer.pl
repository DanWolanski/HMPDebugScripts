#!/usr/bin/perl
#print "Opening $ARGV[0] for parsing....\n";

@files = <rtf*.txt>;

$timestampformat = "^../../20.. (..:..:..\....)";

print "Parsing:\n";
#Find all the Call sessions
my $firstline = "";
my $lastline = "";
foreach $file (@files) {
  print "    $file\n";
  open (MYFILE, $file);
  open (OUTFILE,"$file.sanitized");
     while (<MYFILE>) {
		else{
			print OUTFILE $_;
       }
	}
   print "Operation COmplete - See Output file for details\n";
   print "\n";
  #exit
