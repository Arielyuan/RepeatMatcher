#!/usr/bin/perl

use strict;
use warnings;
use lib './lib';
use NCBIBlastSearchEngine;
use WUBlastSearchEngine;
use CrossmatchSearchEngine;
use SearchEngineI;
use SearchResultCollection;
use Data::Dumpler;

my $NCBIEngine = NCBIBlastSearchEngine->new(pathToEngine=>"/usr/local/rmblast/bin/rmblastn" );
$NCBIEngine->setMatrix( "/home/asmit/Matrices/simple.matrix" );
$NCBIEngine->setQuery( "./gator_annotation/rep" );
$NCBIEngine->setSubject( "./gator_annotation/allMis0.fa" );
my $searchResults = $NCBIEngine->search();

print Dumper($searchResults);
