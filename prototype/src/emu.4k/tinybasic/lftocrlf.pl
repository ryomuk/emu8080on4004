#!/usr/bin/perl
while(<>){
    s/\n$/\r\n/;
    print $_
}
