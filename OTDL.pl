#!/usr/bin/perl
# 
# ************************************************************************** #
#  OTDL.pl program for formatting One Touch text files into a csv form. Also
#          can read Medtronic Carelink Data CSV files that have been
#          "massaged" into looking like Ultra2 meter dump.
#
#    Copyright (C) 2017,2018  Kurt F. Dickason
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# ************************************************************************** #
# AUTHOR:
# Kurt F. Dickason
# 3711 Majestic Circle Ct
# Saint Charles, MO 63303
# e-mail: kd.dccllc@gmail.com
#
# ************************************************************************** #
#
### One Touch Ultra Format (OLD, not in scope, for reference)
#--------------------------
# Data File Examples: OTDL_2006-0527.TXT
#P 150,"QTZ0004CT","MG/DL " 05B3
#P "SAT","05/27/06","16:42:08   ","  051 ", 00 0829
#P "SAT","05/27/06","14:15:48   ","  073 ", 00 082F
#P "SAT","05/27/06","11:28:48   ","  059 ", 00 0834
#P "SAT","05/27/06","10:09:40   ","  057 ", 00 0828
#P "SAT","05/27/06","07:29:40   ","  143 ", 00 082C
#P "SAT","05/27/06","00:15:24   ","  132 ", 00 0820
#P "FRI","05/26/06","21:51:08   ","  053 ", 00 081F
#P "FRI","05/26/06","19:43:16   ","  123 ", 00 0824
#P "FRI","05/26/06","15:02:24   ","  134 ", 00 081C
#P "FRI","05/26/06","12:04:32   ","  068 ", 00 0820
#P "FRI","05/26/06","10:54:24   ","  083 ", 00 0821
#
### One Touch Ultra 2 Format (current, in scope)
#--------------------------
#P 040,"ZSK2326BY","MG/DL " 05B7
#P "SUN","03/07/10","11:09:13   ","  086 ","N","00", 00 09BE
#P "SUN","03/07/10","10:28:08   ","  141 ","N","00", 00 09BA
#P "SUN","03/07/10","07:47:17   ","  177 ","N","00", 00 09CA
#P "SAT","03/06/10","23:24:47   ","  112 ","N","00", 00 09AC
#P "SAT","03/06/10","20:35:10   ","  137 ","N","00", 00 09A8
#P "SAT","03/06/10","18:09:54   ","  122 ","N","00", 00 09B2
#P "SAT","03/06/10","16:35:12   ","  130 ","N","00", 00 09A8
#.
#.
#.
################################################################
# ^^ Note that the list is in reverse chronological order ^^
#
#
# There is one row of meter information that is not relevent here.
# eg. P 500,"ZSK2326BY","MG/DL " 05B8
#
#All following ROW's Target Data:
#         VVVVVVVV   VV              VVV
#P "SAT","03/06/10","16:35:12   ","  130 ","N","00", 00 09A8
#         ^^^^^^^^   ^^              ^^^
#
#
#
# Example format I want:
#
# Heading:
# ,,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,00,01,02,03
#
# 1st Row:
# 05/27/06,S, -,-,-,143,-,-,057,059,-,-,073,-,051,-,-,-,-,-,-,-,-,-,-,-
# H Val             7       10  11      14    16
# Hour              ^       ^   ^       ^     ^
# Next Row:
# 05/28/06,S, -,-,101,243,-,157,-,090,-,-,173,-,251,-,-,-,-,-,-,-,-,-,-,-
# H Val           6   7     9     11      14    16
# Hour              ^       ^     ^       ^     ^

# INCLUDES
# From CPAN John Von Essen > Date-Day-1.04 > Date::Day
# (http://search.cpan.org/~essenz/Date-Day-1.04/Day.pm)
# Had to gunzip, untar, make, make install, test.pl
# Returns the day of the week from any date.
use Date::Day

#DECLARATIONS		#TYPE		#SOURCE		#DESCRIPTION
my $DEBUG=0;		#int (flag)			# Flag to indicate print debug output
my %a;			#hash				# $a{$h} - Array(hash) of values to print for the current day; csv row data for the hour
my $date1="00/00/00";	#string		#$_		# NEW Date of current record; String compared to $date2
my $date2;		#string		#$_		# CURRENT Date of working row data (for csv file); String compared to $date1
my $day;		#string		#$_		# Day of the week
my $div;		#int		#  		# Divisor - number of cumulated values in the current hour read.
my $first=1;		#int (flag)	#{0,1}		# Flag for first row of data (0=false,1=true)
my @h=("04","05","06","07","08","09",
       "10","11","12","13","14","15",
       "16","17","18","19","20","21",
       "22","23","00","01","02","03");
			#const array			# @h=array of hours
my %in;			#string				# Input buffer of raw values
my $i;			#int				# incrementer
my $l=0;		#int				# Line counter
my $sumlist;		#string		#$a{hr}		# list of sum values for multiple values in an hour
my $time;		#string		#$_		# data record's time value
my $time0="04";		#const string			# starting hour of the day in spreadsheet
my $val;		#int		#$_		# value of reading
my $rest;		#string		#$_		# buffer to hold the discarded buffer contents in split
#--------
my $h;			#int		#$time		# Hour
my $m;			#int		#$time		# Minute
my $s;			#int		#$time		# Second

#---------------

#
# Open a text/txt file for formatting into a csv output
#
open (F1,$ARGV[0]) || die "Cannot open file $ARGV[0]";

#
# While read data is true work on the input ($_)
#
while (<F1>) {
	chomp;					# Remove LF/NL
	chop if /\r/;				# Remove DOS CR
	s/P //;					# Remove line Prefix
	s/"//g;					# Remove quote character
	#					# Input now looks like
	#					# FRI,05/26/06,10:54:24,083,000821
	s/ //g;					# Remove spaces
	print "DEBUG: [$_]\n" if $DEBUG;
	if ( /^[MTWFS]/ ) {
		$in{$l}=$_; 			# Save it in input buffer{line#}
		print "DEBUG: [l=$l][in{$l}=$in{$l}]\n" if $DEBUG;
		$l++;
	} # End-if
} # End-while

#
# Init row data with '-'s
#
foreach $i (@h) {
	$a{$i}="-";
}	# End-foreach

#
# Print the Heading
#
print ",,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,00,01,02,03\n";
#
# Start with last row since data read is in reverse chronological order and
# decrement. Also value of $l = n+1 records so decrement 1st before working
# with data
#
while ($l-- >= 0) {
	# --- Assign record data to default var
	$_=$in{$l};
	print "DEBUG: [l=$l][in{$l}=$in{$l}]\n" if $DEBUG;
	# --- Assign record fields to declared vars
	($day,$date2,$time,$val,$rest)=split(/,/);
	# --- Assign time values to declared vars. Mostly interested in $h
	($h,$m,$s)=split(/:/,$time);
	($MM,$DD,$YYYY)=split(/\//,$date2);
    $date2=sprintf("%02d/%02d/%d",$MM,$DD,$YYYY);
	# --- If (the dates are different) AND (the value is >= the start hour of the next day) then print existing data and start a new record
	if (($date2 ne $date1) and ($h ge $time0)) {
		# 
		# Process for next day
		#
		# --- Save the current record date as the new working row date
		$date1=$date2;
		# --- Set the current day
		$day = &day($MM,$DD,$YYYY);
		$day=~s/^(.)..*/\1/;
		# --- If the first pass just print out the date and continue processing.
		if ( $first == 1 ) {
			# --- Print the start of row 01/01/12 (mm/dd/yy) and the day-of-week (Mon,Tue,...)
			print "$date2,$day";
			# --- Reset $first flag to false(0)
			$first=0;
		}	# End-if
		else {
			#
			# Process for same day
			#
			# --- Print values in the array
			foreach $i (@h) {
				print ",$a{$i}";
			}	# End-foreach
			print "\n";
			# --- Init values in the array
			foreach $i (@h) {
				$a{$i}="-";
			}	# End-foreach
			# --- Print the start of row 01/01/12 (mm/dd/yy) and the day-of-week (Mon,Tue,...)
			print "$date2,$day";
		}	# End-else
	}	# End-if
	#
	# Assign values to %a (row data)
	# 
	# --- If the hour of $a{$h} value is not initialized (= '-') then assign the value
	if ($a{$h} eq "-") {
		$a{$h}=$val;
	}	# End-if
	# --- otherwise average the current hour values with the existing value
	# --- output will look like an excel formula ie. '=(x1+x2+x3)/n' eg. =(101+202+303)/3
	else {
		# --- If we have (s then been through this hour before
		if ( $a{$h} =~ m/=\(/ ) {
			# --- remove = & (s
			$a{$h}=~s/=\(//;
			# --- remove )s
			$a{$h}=~s/\)//;
			# --- split formaula to find current divisor
			($sumlist,$div)=split(/\//,$a{$h});
			# --- Increment divisor 
			$div++;
			# --- Remove divisor and / from values so $a{$h}=x1+x2+x3 e.g. 101+202+303
			$a{$h}=~s/\/.*//;
			$a{$h}=$sumlist;
		}	# End-if
		else {
			# --- no (s so this is 2nd value to append to list (x1+x2)/n (eg. 101+202/2)
			$div=2;
		}	# End-else
		# --- Add value to list of data for the hour and divides by the divisor (ie. x1+x2+...+xn/n)
		$a{$h}="=(".$a{$h}."+".$val.")/".$div;
	}	# End-else
}	# End-While

# --- Print last Row's values in the array
foreach $i (@h) {
	print ",$a{$i}";
}	# End-foreach
print "\n";

#
### END
#
# REVISIONS
# WHO   Date/Ver    Description
# ---   ---------   ----------------------------------------------------------  
# KFD   2018-0103   Added new functionality for computing day of the week
#       1.2         from the date rather than using the file. This is to
#                   accomodate downloaded Medtronic CSV files (no day is
#                   recorded).
