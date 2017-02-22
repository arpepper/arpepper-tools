#!/bin/awk
#
# do_one_arg(s) - process single given option "s"
#
function do_one_arg(s, sense, type) {
	sense = substr(s,1,1);
	if (sense != "+" && sense != "-") return 0;
	type = substr(s,2,1);
	if (type == "H" && length(s) > 2) {
		if (substr(s,3,1) != "=") return 0;
		if (sense == "+")
			header[substr(s,4)] = 1;
		else {
			delete header[substr(s,4)];
		}
	}
	else if (type == "H") {
# show all headers we know about
		for (type in sf) {
			if (sf[type] !~ /^:/ ) {
				if (sense == "+")
					header[sf[type]] = 1;
				else
					delete header[sf[type]];
			}
		}
	}
	else {
		if (length(s) == 2 && sf[type]) {
			if (sense == "+")
				header[sf[type]] = 1;
			else {
				delete header[sf[type]];
			}
		}
		else {
			return 0;
		}
	}
	return 1;
}
#
# graboptions() - grab options (and files) from current ARGC, ARGV
#
function graboptions(line,i,flag) {
	nopt = 0;
	nargc = 0;
	options[0] = "";
	files[filec] = "";
#print ARGC;
	flag = 0;
	if ( ARGC ) {
		for (i = 1; i < ARGC; ++i) {
#print i, ARGV[i];
			if (ARGV[i]) {
				if (flag == 0 && ARGV[i] == "dummy") {
					flag = 1;
				}
				else if (flag) {
					if (substr(ARGV[i],1,1) ~ /[+-]/)
						options[nopt++] = ARGV[i];
					else
						files[filec++] = ARGV[i];
				}
			}
			delete ARGV[i];
		}
# following silly kludge seems necessary with nawk and derivatives
		if (options[nopt-1] == "") --nopt;
	}
	ARGC = 1;
	if (filec == 0) {
		ARGC = 2;
		ARGV[1] = "-";    # force processing of stdin
	}
#for (i = 0; i < filec; ++i) {
#	print i, files[i];
#}
}
#
# splitrev(r,a) - split given rev into given array
#
function splitrev(r,a,cr,i,j,n,l) {
	# how stupid, we have to do this without using split
	n = 0;
	i = 1;
	l = length(r);
	while (i <= l) {
		j = i;
		while (j <= l && substr(r,j,1) != ".") {
			++j;
		}
		a[++n] = substr(r,i,j-i);
		i = j+1;
	}
	return n;
	# following should work, but does not
	cr = r;
	# if we do not do this, awk parses token 1.2 before breaking fields...
	gsub(/[.]/,":",cr);
	return split(cr,a,"/:/");
	# no, actually it does not work even if we do the gsub...
}
#
# acmp(a1,n1,a2,n2) - return -1,0, or 1 reflecting comparison of arrays
#
function acmp(a1,n1,a2,n2,i) {
	for (i = 1; i <= n1 && i <= n2; ++i) {
		if (a1[i]+0 > a2[i]+0) return 1;
		if (a1[i]+0 < a2[i]+0) return -1;
	}
	if (n1 > n2) return 1;
	if (n1 < n2) return -1;
	return 0;
}
#
# revcmp(r1,r2) - return -1,0, or 1 reflecting comparison of revisions
#
function revcmp(r1,r2,a1,a2,n1,n2) {
	n1 = splitrev(r1,a1);
	n2 = splitrev(r2,a2);
	return acmp(a1,n1,a2,n2);
}
#
# increv(r); increment the given revision to next one
#    1.1 -> 1.2
#    1.1.0.1 -> 1.1.0.2
#
function increv(r,a,n,rr,s,i) {
	rr = r;
	n = splitrev(rr,a);
	++a[n];
	s = a[1];
	for (i = 2; i <= n; ++i)
		s = s "." a[i];
	return s;
}
#
# insrev() - insert revision info from current "revision " line
#
function insrev(line,i,j) {
# revision 1.1	locked by: jmsellens;
#	revlist[f[2]] = f[2];
#
# As one might guess, this is hideously slow if nrev > 64 or so
#
	if (nrev == 0) {
		nrev = 1
		sortrev[1] = f[2];
	}
	else {
#
# gosh, perhaps sometime you could try binary seach (great for new bugs)
#
		for (i = 1; i <= nrev; ++i) {
			j = revcmp(f[2],sortrev[i]);
			if (j <= 0)
				break;
		}
		if (j != 0 || i > nrev) {
			++nrev;
			for (j = nrev; j > i; --j)
				sortrev[j] = sortrev[j-1];
			sortrev[i] = f[2];
			break;
		}
	}
}
#
# addauthor() - add author info from current "date, etc" line
#
function addauthor(line) {
#date: 1995/11/26 14:30:59;  author: arpepper;  state: Exp;

	# should work, else search for "author"
	authlist[f[5]] = f[5];
}
#
# sumlists()
#
function sumlists(i,j,s,buf,prevrev,mode) {
	if (sumrevisions) {
		print ""
		print "revision summary:"
		buf = "";
		prevrev = "0";
		mode = "";
		for (i = 1; i <= nrev; ++i) {
			s = sortrev[i];
			if (increv(prevrev) == s) {
				mode = ":";
				prevrev = s;
			}
			else {
				if (mode == ":") {
					buf = sprintf("%s:%s",buf,prevrev);
				}
				else {
				}
				# 60 should be a parameter?
				if (mode != ":" && length(buf) > 60) {
					buf = sprintf("%s%s",buf,mode);
					print buf;
					buf = "";
					mode = "";
				}
				if (mode == ":") mode = ", ";
				buf = sprintf("%s%s%s",buf,mode,s);
				mode = ", ";
				prevrev = s;
			}
		}
		if (mode == ":") {
			buf = sprintf("%s:%s",buf,prevrev);
		}
		if (length(buf) > 0) {
			print buf;
		}
	}
	if (listrevisions) {
		for (i = 1; i <= nrev; ++i) {
			print sortrev[i];
		}
	}
	for (i in sortrev) {
		delete sortrev[i];
	}
	nrev = 0;
	if (sumauthors) {
		print ""
		print "author list:"
		for (i in authlist) {
			print authlist[i];
		}
	}
	for (i in authlist) {
		delete authlist[i];
	}
}
#
# doheaders() - process the lines between BOF and "-------" line, or
#  between "========" and next "-------"
#
function doheaders(i) {
	if ( $0 ~ /^------/) {
		printing = 0;
		seenminus = 1;
	}
	else if ( $0 !~ /^[ \t]/ && $0 ~ /:/) {
		printing = 0;
		for ( i in header ) {
			if ( $0 ~ "^" i ":" ) {
				printing = 1;
				break;
			}
		}
	}
	if (printing) print $0
}
#
# dorevisions() - process the lines between "-------" and next "======="
#   possibly in a file
#
function dorevisions(printit)
{
#print "dorevisions..." $0
	printit = 0;
	if ( allrevisions ) {
		printit = 1;
	}
	if ( $0 ~ /^===========/) {
		if (showequals) printit = 1;
		sumlists();
	}
	if (prevminus && $0 ~ /^revision/) {
		# revision line for revision
		prevrev = 1;
		if (showauthors) printit = 1;
		if (saverevs) insrev($0);
	}
	else if (prevrev) {
		# date, author, etc. line
		if (showauthors) printit = 1;
		addauthor($0);
		prevrev = 0;
	}
	if (printit) print $0;
	prevminus = ( $0 ~ /^------/ );
}
BEGIN {
	headeri = 0;
	sf["R"] = "RCS file";
	sf["W"] = "Working file";
	sf["h"] = "head";
	sf["b"] = "branch";
	sf["l"] = "locks";
	sf["s"] = "symbolic names";
	sf["c"] = "comment leader"
	sf["k"] = "keyword substitution"
	sf["t"] = "total revisions"
	sf["d"] = "description"
	sf["r"] = ":sumrevisions"
	sf["v"] = ":listrevisions"
	sf["V"] = ":allrevisions"
	sf["a"] = ":sumauthors"
	sf["A"] = ":showauthors"
	sf["E"] = ":showequals"
# set defaults +W +l +d +r +E
	header[sf["W"]] = 1;	# also makes sure header is an array
	header[sf["l"]] = 1;
	header[sf["d"]] = 1;
	header[sf["r"]] = 1;
	header[sf["E"]] = 1;
	graboptions();
#print "nopt=" nopt;
	error = 0;
	for (i = 0; i < nopt; ++i) {
#print i, options[i];
		if (do_one_arg(options[i]) == 0) {
			printf("%d,%s: unrecognized\n", i, options[i]);
			error = 1;
		}
	}
	nrev = 0;

	sumrevisions = 0;
	listrevisions = 0;
	allrevisions = 0;
	sumauthors = 0;
	showauthors = 0;
	# note allrevisions does not require sortrev be maintained
	if (header[":sumrevisions"]) {
		sumrevisions = 1;
	}
	if (header[":listrevisions"]) {
			listrevisions = 1;
	}
	if (header[":allrevisions"]) {
			allrevisions = 1;
	}
	if (header[":sumauthors"]) {
			sumauthors = 1;
	}
	if (header[":showauthors"]) {
			showauthors = 1;
	}
	if (header[":showequals"]) {
			showequals = 1;
	}
	saverevs = (sumrevisions || listrevisions);
	if (error) exit(1);
#print "filec=" filec;
	for (filei = 0; filei < filec; ++filei) {
		reci = 0;
		isheader = 1;
		isrev = 0;
		while ("rlog " files[filei] | getline) {
			doline(++reci,$0);
		}
	}
# MKS awk processes stdin even with empty ARGV
	if (filec != 0) exit;
}
function doline(nr,line,xline) {
	xline = line;
	nf = split(xline,f);
	if (nr == 1) isheader = 1;
	if (xline ~ /^-------/) {
		isheader = 0;
	}
	if (isheader) {
		doheaders();
	}
	else {
		dorevisions();
	}
	if (xline ~ /^===========/) isheader = 1;
}
{
	doline(NR,$0);
}
END {
#	for (i = 1; i <= headeri; ++i) {
#		print i, header[i];
#	}
}
