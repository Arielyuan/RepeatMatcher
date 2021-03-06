#!/usr/bin/perl

=head1 NAME

RepeatMatcherGUI.pl

=head1 DESCRIPTION

Create a graphic user interface to annotate RepeatModeler consensi.

=head1 USAGE

    perl RepeatMatcherGUI [PARAMETERS]

    Parameter      Description
    -o --out       Output file with final sequences (Fasta)
    -x --exclude   Output file with excluded sequences (Fasta)
    -i --input     Input file (Fasta)
    -s --self      Self-comparison of input (cross_match output)
    -a --align     Alignments of input to a reference (cross_match output)
    -b --repblast  Blast output of repeat peptides comparison (blast output)
    -n --nrblast   Blast output of NR peptides comparison (blast output)
    -f --fold      Sequence fold output directory (RNAfold output as PNGs)
    -l --log       Write log file here (used to keep track of progress)
    -r --reload    Reload a previous project

    -v --verbose   Verbose mode
    -h --help      Print this screen
    --version      Print version
    
=head1 EXAMPLES

    1. Start a new project
    perl RepeatMatcherGUI.pl -o OUT -i SEQS -s SELF -a ALIGN -b BLAST -n BLAST -f FOLD -l LOG

    2. Reload a started project
    perl RepeatMatcherGUI.pl -r LOG

=head1 AUTHOR

Juan Caballero, Institute for Systems Biology @ 2012

=head1 CONTACT

jcaballero@systemsbiology.org

=head1 LICENSE

This is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with code.  If not, see <http://www.gnu.org/licenses/>.

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Tk;
use Tk::Hlist;
use Tk::ROText;
use Tk::Label;
use Tk::ItemStyle;
use Tk::Photo;
use Tk::PNG;

# Default parameters
my $help     = undef;         # Print help
my $verbose  = undef;         # Verbose mode
my $version  = undef;         # Version call flag
my $out      = undef;
my $in       = undef;
my $self     = undef;
my $align    = undef;
my $repblast = undef;
my $nrblast  = undef;
my $fold     = undef;
my $log      = undef;
my $reload   = undef;
my $exclude  = undef;

# Main variables
my $our_version = 0.1;        # Script version number
# %data => is the main struct
# $data{$id}
#            |-> label    : sequence fasta comment
#            |-> seq      : nucleotide sequence
#            |-> self     : sequence self-comparisons
#            |-> align    : sequence alignments to reference nucleotides
#            |-> repblast : sequence alignments to reference peptides
#            |-> nrblast  : sequence alignments to NR database
#            |-> fold     : sequence fold image path
#            |-> delete   : delete flag
#            |-> reverse  : reverse flag
#            |-> newlabel : new (edited) label for sequence
#            |-> question : question mark flag
#            |-> list     : position in Hlist
#            |-> status   : flag for finished sequences
my %data;
my %classes;
my @classes;
my $box_width  = 100;
my $box_height = 30;
my ($call_id, $delete, $reverse, $question);

# Calling options
GetOptions(
    'h|help'           => \$help,
    'v|verbose'        => \$verbose,
    'version'          => \$version,
    'o|out=s'          => \$out,
    'i|in=s'           => \$in,
    's|self=s'         => \$self,
    'a|align=s'        => \$align,
    'b|repblast=s'     => \$repblast,
    'n|nrblast=s'      => \$nrblast,
    'f|fold=s'         => \$fold,
    'l|log=s'          => \$log,
    'r|reload:s'       => \$reload,
    'x|exclude:s'      => \$exclude    
) or pod2usage(-verbose => 2);
printVersion() if (defined $version);    
pod2usage(-verbose => 2) if (defined $help);
pod2usage(-verbose => 2) unless (defined $log or defined $reload);

if (defined $reload) {
    reloadProject($reload);
}
else {
    die "missing sequence file (-i)\n"        unless (defined $in);
#    die "missing self-comparison file (-s)\n" unless (defined $self);
#    die "missing alignments file (-a)\n"      unless (defined $align);
#    die "missing repeats blast file (-b)\n"   unless (defined $repblast);
#    die "missing NR blast file (-n)\n"        unless (defined $nrblast);
#    die "missing dna fold dir (-f)\n"         unless (defined $fold);
    die "missing output file (-o)\n"          unless (defined $out);
    die "missing exclude file (-e)\n"         unless (defined $exclude);
    startLog($log);
}

# load data from files in %data
loadIn();
loadSelf();
loadAlign();
loadRepBlast();
loadNRBlast();
loadFold();
loadRepClasses();

my @ids = sort (keys %data);

# Create the GUI
my $mw          =  MainWindow -> new(); # Main Window
   $mw          -> title('RepeatMatcherGUI');

# Edit frame
my $edit_frame  =  $mw         ->      Frame();
my $id_label    =  $edit_frame ->      Label(-width  => 30);
my $class_entry =  $edit_frame ->      Entry(-width  => 20, -background => 'white');
my $rep_button  =  $edit_frame -> Menubutton(-text   => 'Repeat Family',
                                             -relief => 'raised'
                                            );
my $rep_menu    =  $rep_button ->       Menu();
my $dna_menu    =  $rep_menu   ->    cascade(-label  => 'DNA');
my $dnahat_menu =  $rep_menu   ->    cascade(-label  => 'DNA/hAT');
my $dnatcm_menu =  $rep_menu   ->    cascade(-label  => 'DNA/TcMar');
my $line_menu   =  $rep_menu   ->    cascade(-label  => 'LINE');
my $ltr_menu    =  $rep_menu   ->    cascade(-label  => 'LTR');
my $sine_menu   =  $rep_menu   ->    cascade(-label  => 'SINE');
my $sat_menu    =  $rep_menu   ->    cascade(-label  => 'Satellite');
my $other_menu  =  $rep_menu   ->    cascade(-label  => 'Other');
foreach my $rep (@classes) {
    if    ($rep =~ m#^DNA/hAT#) {
        $dnahat_menu -> command(-label   => $rep, 
                                -command => sub { 
                                                 $class_entry -> configure(-text => $rep); 
                                                }
                                );
    }
    elsif ($rep =~ m#^DNA/TcMar#) {
        $dnatcm_menu -> command(-label => $rep, 
                                -command => sub { 
                                                 $class_entry -> configure(-text => $rep); 
                                                }
                                );
    }
    elsif ($rep =~ m/^DNA/) {
        $dna_menu    -> command(-label => $rep, 
                                -command => sub { 
                                                 $class_entry -> configure(-text => $rep); 
                                                }
                                );
    }
    elsif ($rep =~ m/^LINE/) {
        $line_menu   -> command(-label => $rep, 
                                -command => sub { 
                                                 $class_entry -> configure(-text => $rep); 
                                                }
                                );
    }
    elsif ($rep =~ m/^LTR/) {
        $ltr_menu    -> command(-label => $rep, 
                                -command => sub { 
                                                 $class_entry -> configure(-text => $rep); 
                                                }
                                );
    }
    elsif ($rep =~ m/^SINE/) {
        $sine_menu   -> command(-label => $rep, 
                                -command => sub { 
                                                 $class_entry -> configure(-text => $rep); 
                                                }
                                );
    }
    elsif ($rep =~ m/^Satellite/) {
        $sat_menu    -> command(-label => $rep, 
                                -command => sub { 
                                                 $class_entry -> configure(-text => $rep); 
                                                }
                                );
    }
    else {
        $other_menu  -> command(-label => $rep, 
                                -command => sub { 
                                                 $class_entry -> configure(-text => $rep); 
                                                }
                                );
    }
}
$rep_button -> configure(-menu => $rep_menu);

my $qm_checkbox   = $edit_frame -> Checkbutton(-text       => '?', 
                                               -variable   => \$question,
                                               -command    => sub {
                                                                   $data{$call_id}{'question'} = $question;
                                                                  }
                                              );

my $info_entry    = $edit_frame ->       Entry(-width      => 60, 
                                               -background => 'white'
                                              );

my $update_button = $edit_frame ->      Button(-text       => 'Update', 
                                               -command => \&updateSeq
                                              );

my $rev_checkbox  = $edit_frame -> Checkbutton(-text       => 'Reverse', 
                                               -variable => \$reverse,
                                               -command    => sub {
                                                                   $data{$call_id}{'reverse'} = $reverse;
                                                                  }
                                              );

my $del_checkbox  = $edit_frame -> Checkbutton(-text       => 'Exclude', 
                                               -variable => \$delete, 
                                               -command    => sub {
                                                                   $data{$call_id}{'delete'} = $delete;
                                                                  }
                                              );
my $fasta_button  = $edit_frame ->      Button(-text       => 'Export Fasta', 
                                               -command    => \&writeFasta
                                              );

# IDs list frame
my $id_hlist      = $mw         ->    Scrolled('HList',
                                               -scrollbars => "ow",
                                               -itemtype   => 'text',
                                               -separator  => '#',
                                               -selectmode => 'single',
                                               -width      => 25, 
                                               -height     => $box_height,
                                               -background => 'white',
                                               -browsecmd  => sub {
                                                                   my $call = shift;
                                                                   my @call = split(/#/, $call);
                                                                   $call_id = pop @call;
                                                                   &callID();
                                                                  }
                                              );

my $done_style   = $id_hlist    ->   ItemStyle('text', 
                                                -foreground => 'blue',
                                                -background => 'white'
                                               );

my $done2_style  = $id_hlist    ->   ItemStyle('text', 
                                               -foreground => 'red',
                                               -background => 'white'
                                              );

my $undone_style = $id_hlist    ->   ItemStyle('text', 
                                               -foreground => 'black', 
                                               -background => 'white'
                                              );

$id_hlist -> add("#",  # root node
                 -text => "#", 
                 -style => $undone_style
                ); 

foreach my $class (sort keys %classes) {
    $id_hlist -> add("#$class", 
                     -text  => $class, 
                     -style => $undone_style
                    );
}

foreach my $id (@ids) {
    next unless (defined $data{$id}{'class'});
    my $class  = $data{$id}{'class'};
    my $status = $data{$id}{'status'};
    if ($status == 1) {
        if ($data{$id}{'label'} ne $data{$id}{'newlabel'} or 
            $data{$id}{'reverse'} == 1                    or 
            $data{$id}{'delete'}  == 1) {
                $id_hlist -> add("#$class#$id", 
                                 -text => $id, 
                                 -style => $done2_style
                                );
        }
        else {
                $id_hlist -> add("#$class#$id", 
                                 -text => $id, 
                                 -style => $done_style
                                );
        }
    }
    else {
                $id_hlist -> add("#$class#$id", 
                                 -text => $id, 
                                 -style => $undone_style
                                );
    }
}

# Geometry

$id_hlist      -> pack(-side => 'left');
$edit_frame    -> pack(-side => 'right');
$id_label      -> grid(-row => 0, -column => 0);
$class_entry   -> grid(-row => 1, -column => 0);
$rep_button    -> grid(-row => 1, -column => 1);
$qm_checkbox   -> grid(-row => 1, -column => 2);
$info_entry    -> grid(-row => 2, -column => 0, -columnspan => 3);
$rev_checkbox  -> grid(-row => 0, -column => 1);
$del_checkbox  -> grid(-row => 0, -column => 2);
$update_button -> grid(-row => 3, -column => 0);
$fasta_button  -> grid(-row => 3, -column => 1);

# Sequence frame
my $seq_win       = $mw           -> Toplevel(-title      => 'Sequence',
                                              -width      => $box_width, 
                                              -height     => $box_height
                                             );
my $seq_txt       = $seq_win      -> Scrolled('ROText', 
                                              -scrollbars => "osoe", 
                                              -background => 'white',
                                              -wrap       => 'none'
                                             ) -> pack(-expand => 1, -fill => 'both');

# Align frame
my $align_win     = $mw           -> Toplevel(-title      => 'Alignment with known repeats (nuc)',
                                              -width      => $box_width, 
                                              -height     => $box_height
                                             );
my $align_txt     = $align_win    -> Scrolled('ROText', 
                                              -scrollbars => "osoe", 
                                              -background => 'white',
                                              -wrap       => 'none'
                                             ) -> pack(-expand => 1, -fill => 'both');

# Self frame
my $self_win      = $mw           -> Toplevel(-title      => 'Self-alignments',
                                              -width      => $box_width, 
                                              -height     => $box_height
                                             );
my $self_txt      = $self_win     -> Scrolled('ROText', 
                                              -scrollbars => "se", 
                                              -background => 'white',
                                              -wrap       => 'none'
                                             ) -> pack(-expand => 1, -fill => 'both');

# Repeats Blast frame
my $repblast_win  =  $mw          -> Toplevel(-title      => 'Alignment with known repeats (pep)',
                                              -width      => $box_width, 
                                              -height     => $box_height
                                             );
my $repblast_txt  = $repblast_win -> Scrolled('ROText', 
                                              -scrollbars => "osoe", 
                                              -background => 'white',
                                              -wrap       => 'none'
                                             ) -> pack(-expand => 1, -fill => 'both');

# NR Blast frame
my $nrblast_win   = $mw           -> Toplevel(-title      => 'Alignment with NR (pep)',
                                              -width      => $box_width, 
                                              -height     => $box_height
                                             );
my $nrblast_txt   = $nrblast_win  -> Scrolled('ROText', 
                                              -scrollbars => "osoe", 
                                              -background => 'white',
                                              -wrap       => 'none'
                                             ) -> pack(-expand => 1, -fill => 'both');

# Fold frame
my $fold_win      = $mw           -> Toplevel(-title      => 'Sequence folding');
my $fold_img      = $fold_win;
if (-e "RepeatMatcher.png") {
    $fold_img     = $fold_win     ->    Photo(-file       => "RepeatMatcher.png");
}
my $fold_lab      = $fold_win     -> Scrolled('Label',
                                              -scrollbars => "osoe",
                                              -image      => $fold_img,
                                              -width      => 600, 
                                              -height     => 300,
                                              -background => 'white'
                                             ) -> pack(-expand => 1, -fill => 'both');

MainLoop();

###################################
####   S U B R O U T I N E S   ####
###################################

sub printVersion {
    print "$0 $our_version\n";
    exit 1;
}

sub startLog {
    my $file = shift @_;
    my $ver  = 0;
    $ver = 1 if (defined $verbose);
    warn "creating LOG in $file\n" if (defined $verbose);
    open LOG, ">$file" or die "cannot open $file\n";
    print LOG <<_LOG_   
# RepeatMatcherGUI log file
seq_file: $in
out_file: $out
log_file: $log
self_file: $self
align_file: $align
fold_file: $fold
nrblast_file: $nrblast
repblast_file: $repblast
exclude_file: $exclude
verbose_mode: $ver
_LOG_
;
close LOG;
}

sub reloadProject {
    my $file = shift @_;
    warn "reading info from LOG in $file\n" if (defined $verbose);
    open LOG, "$file" or die "cannot open $file\n";
    while (<LOG>) {
        chomp;
        next if (m/^#/);
        if    (m/^seq_file: (.+)/)      { $in       = $1; }
        elsif (m/^out_file: (.+)/)      { $out      = $1; }
        elsif (m/^log_file: (.+)/)      { $log      = $1; }
        elsif (m/^self_file: (.+)/)     { $self     = $1; }
        elsif (m/^align_file: (.+)/)    { $align    = $1; }
        elsif (m/^nrblast_file: (.+)/)  { $nrblast  = $1; }
        elsif (m/^fold_file: (.+)/)     { $fold     = $1; }
        elsif (m/^repblast_file: (.+)/) { $repblast = $1; }
        elsif (m/^exclude_file: (.+)/)  { $exclude  = $1; }
        elsif (m/^verbose_mode: (.+)/)  { $verbose  = $1; }
        else {
            my ($id, $del, $rev, $new) = split (/\t/, $_);
            $data{$id}{'delete'}   = $del;
            $data{$id}{'reverse'}  = $rev;
            if ($new =~ m/.+?#(.+?) /) {
                my $class = $1;
                $data{$id}{'class'}    = $class;
                $data{$id}{'newlabel'} = $new;
                $data{$id}{'question'} = 1 if ($class =~ m/\?/);
                $classes{$class}       = 1;
            }
            $data{$id}{'status'}   = 1;
        }
    }
    $verbose = undef if ($verbose == 0);
    close LOG;
}

sub loadIn {
    warn "Loading sequences from $in\n" if (defined $verbose);
    open FASTA, "$in" or die "cannot open file $in\n";
    my $id;
    my $class;
    while (<FASTA>) {
        chomp;
        if (m/>(.+)#(.+)/) {
            $id    = $1;
            $class = $2;
            s/>//;
            chomp;
            $data{$id}{'label'}    = $_;
            unless (defined $data{$id}{$class}) {
                $data{$id}{'class'}    = $class;
                $classes{$class} = 1;
            }
                
            $data{$id}{'delete'}   = 0  unless (defined $data{$id}{'delete'});
            $data{$id}{'reverse'}  = 0  unless (defined $data{$id}{'reverse'});
            $data{$id}{'newlabel'} = $_ unless (defined $data{$id}{'newlabel'});
            $data{$id}{'question'} = 0  unless (defined $data{$id}{'question'});
            $data{$id}{'status'}   = 0  unless (defined $data{$id}{'status'});
        }
        elsif (m/>(.+)/) {
            $id    = $1;
            $class = 'NoClass';
            s/>//;
            chomp;
            $data{$id}{'label'}     = $_;
            unless (defined $data{$id}{$class}) {
                $data{$id}{'class'} = $class;
                $classes{$class}    = 1;
            }
                
            $data{$id}{'delete'}   = 0  unless (defined $data{$id}{'delete'});
            $data{$id}{'reverse'}  = 0  unless (defined $data{$id}{'reverse'});
            $data{$id}{'newlabel'} = $_ unless (defined $data{$id}{'newlabel'});
            $data{$id}{'question'} = 0  unless (defined $data{$id}{'question'});
            $data{$id}{'status'}   = 0  unless (defined $data{$id}{'status'});
        }
        else {
            $data{$id}{'seq'}   .= "$_\n";
        }
    }
    close FASTA;
}

sub loadAlign {
    warn "loading aligments in $align\n" if (defined $verbose);
    return unless (defined $align);
    open ALIGN, "$align" or die "cannot open file $align\n";
    my $id = 'skip';
    while (<ALIGN>) {
       if (m/^\s*\d+\s+\d+/) {
           s/^\s+//;
           my @a = split (/\s+/, $_);
           $id =  $a[4];
           $id =~ s/#.+$//;
       }
       $data{$id}{'align'} .= $_ if ($id ne 'skip');
    }
    close ALIGN;
}

sub loadSelf {
    warn "loading self-comparison in $self\n" if (defined $verbose);
    return unless (defined $self);
    my ($id1, $id2, $score, $left, $right, $dir);
    my %seen;
    open SELF, "$self" or die "cannot open file $self\n";
    while (<SELF>) {
        next unless (m/^\s*\d+\s+\d+/);
        chomp;
        s/^\s*//;
        my @line  = split (/\s+/, $_);
        $score = "$line[0]\t$line[1]\t$line[2]\t$line[3]";
        $id1   = $line[4];
        $id1   =~ s/#.+$//;
        next if ($id1 =~ m/^\d+$/);
        $left  = "$line[4]\t$line[5]\t$line[6]\t$line[7]";
        if ($line[8] eq 'C') {
            $dir    = '-';
            $id2    = $line[9];
            $right  = "$line[9]\t$line[10]\t$line[11]\t$line[12]";
        }
        else {
            $dir    = '+';
            $id2    = $line[8];
            $right  = "$line[8]\t$line[9]\t$line[10]\t$line[11]";
        }
        $id2   =~ s/#.+$//;
        $data{$id1}{'self'} .= "$score\t$left\t$right\t$dir\n" unless (defined $seen{"$left:$right"});
        $data{$id2}{'self'} .= "$score\t$right\t$left\t$dir\n" unless (defined $seen{"$right:$left"});
        $seen{"$left:$right"} = 1;
        $seen{"$right:$left"} = 1;
    }
    close SELF;
    %seen = ();
}

sub loadRepBlast {
    warn "loading repeats blast aligments in $repblast\n" if (defined $verbose);
    return unless (defined $repblast);
    my $id;
    open BLAST, "$repblast" or die "cannot open file $repblast\n";
    local $/ = "\nBLASTX";
    while (<BLAST>) {
        m/Query= (.+?)\n/;
        $id = $1;
        $id =~ s/#.+$//;
        if (m/No hits found/) {
            $data{$id}{'repblast'} .= 'No hits found';
        }
        else {
            my @hit = split (/\n/, $_);
            pop @hit;
            while (1) {
                my $del = shift @hit;
                last if ($del =~ /Searching/);
            }
            shift @hit;
            shift @hit;
            shift @hit;
            $data{$id}{'repblast'} .= join ("\n", @hit);
        }
    }
    close BLAST;
}

sub loadNRBlast {
    warn "loading NR blast aligments in $nrblast\n" if (defined $verbose);
    return unless (defined $nrblast);
    my $id;
    open BLAST, "$nrblast" or die "cannot open file $nrblast\n";
    local $/ = "\nBLASTX";
    while (<BLAST>) {
        m/Query= (.+?)\n/;
        $id = $1;
        $id =~ s/#.+$//;
        if (m/No hits found/) {
            $data{$id}{'nrblast'} .= 'No hits found';
        }
        else {
            my @hit = split (/\n/, $_);
            pop @hit;
            while (1) {
                my $del = shift @hit;
                last if ($del =~ /Searching/);
            }
            shift @hit;
            shift @hit;
            shift @hit;
            $data{$id}{'nrblast'} .= join ("\n", @hit);
        }
    }
    close BLAST;
}

sub loadFold {
    warn "searching sequence folds in $fold\n" if (defined $verbose);
    return unless (defined $fold);
    my $id;
    opendir FOLD, "$fold" or die "cannot open dir $fold\n";
    while (my $png = readdir FOLD) {
        next unless ($png =~ m/\.png$/);
        $id = $png;
        $id =~ s/\.png$//;
        $data{$id}{'fold'} = "$fold/$png";
    }    
    closedir FOLD;
}

sub callID {
    return unless (defined $call_id);
    my $lab_      = $data{$call_id}{'label'};
    my $seq_      = 'No sequence';
    my $self_     = 'No matches';
    my $align_    = 'No matches';
    my $repblast_ = 'No matches';
    my $nrblast_  = 'No matches';
    my $fold_     = 'RepeatMatcher.png';
    my $class_    = 'No class';
    
    $class_       = $data{$call_id}{'class'}    if (defined $data{$call_id}{'class'});
    $lab_         = $data{$call_id}{'newlabel'} if (defined $data{$call_id}{'newlabel'}); 
    $seq_         = $data{$call_id}{'seq'}      if (defined $data{$call_id}{'seq'});
    $self_        = $data{$call_id}{'self'}     if (defined $data{$call_id}{'self'});
    $align_       = $data{$call_id}{'align'}    if (defined $data{$call_id}{'align'});
    $repblast_    = $data{$call_id}{'repblast'} if (defined $data{$call_id}{'repblast'});
    $nrblast_     = $data{$call_id}{'nrblast'}  if (defined $data{$call_id}{'nrblast'});
    $fold_        = $data{$call_id}{'fold'}     if (defined $data{$call_id}{'fold'});
    
    $seq_txt      -> selectAll;
    $seq_txt      -> deleteSelected;
    $seq_txt      -> insert('end', ">$lab_\n$seq_");
    
    $align_txt    -> selectAll;
    $align_txt    -> deleteSelected;
    $align_txt    -> insert('end', $align_);
    
    $self_txt     -> selectAll;
    $self_txt     -> deleteSelected;
    $self_txt     -> insert('end', $self_);
    
    $repblast_txt -> selectAll;
    $repblast_txt -> deleteSelected;
    $repblast_txt -> insert('end', $repblast_);

    $nrblast_txt  -> selectAll;
    $nrblast_txt  -> deleteSelected;
    $nrblast_txt  -> insert('end', $nrblast_);

    $fold_img     -> blank;
    $fold_img     -> read($fold_);

    $id_label     -> configure(-text => "Repeat: $call_id");
    $class_entry  -> configure(-text => $class_);
    $lab_         =~ s/^.+? //;
    $info_entry   -> configure(-text => $lab_);
     
    if ($data{$call_id}{'reverse'} == 1) {
        $rev_checkbox -> select;
        $reverse = 1;
    }
    else {
        $rev_checkbox -> deselect;
        $reverse = 0;
    }
    
    if ($data{$call_id}{'delete'}  == 1) {
        $del_checkbox -> select;
        $delete = 1;
    }
    else {
        $del_checkbox -> deselect;
        $delete = 0;
    }
    
    if ($data{$call_id}{'question'}  == 1) {
        $qm_checkbox -> select;
        $question = 1;
    }
    else {
        $qm_checkbox -> deselect;
        $question = 0;
    }    
}

sub updateSeq {
    my $rec = '';
    my $del = 0;
    my $rev = 0;
    my $lab = '';
    $del    = 1 if ($data{$call_id}{'delete'}  == 1);
    $rev    = 1 if ($data{$call_id}{'reverse'} == 1);
    
    my $class = $data{$call_id}{'class'};
    
    my $new_class = $class_entry -> get();
    my $new_info  = $info_entry  -> get();
    $new_class .= '?' if ($question == 1 and $new_class !~ m/\?/);
    my $new = "$call_id#$new_class $new_info";
    
    if ($new ne $data{$call_id}{'label'}) {
        $data{$call_id}{'newlabel'} = $new;
        $lab = $new;
    }
    
    open  LOG, ">>$log" or die "cannot open $log\n";
    print LOG "$call_id\t$del\t$rev\t$lab\n";
    warn "LOG> $call_id\t$del\t$rev\t$lab\n" if (defined $verbose);
    close LOG;
    
    if ($lab =~ m/\w+/ or $del == 1 or $rev == 1) {
        $id_hlist -> itemConfigure("#$class#$call_id", 0, -style => $done2_style);
    }
    else {
        $id_hlist -> itemConfigure("#$class#$call_id", 0, -style => $done_style);
    }

}

sub revcomp {
    my $rc  =  '';
    my $sq  =  shift @_;
       $sq  =~ s/\n+//g;
       $sq  =  reverse $sq;
       $sq  =~ tr/ACGTacgt/TGCAtgca/;
    while ($sq) {
        $rc .= substr ($sq, 0, 50);
        $rc .= "\n";
        substr ($sq, 0, 50) = '';
    }
    return $rc;
}

sub writeFasta {
    open OUT, ">$out" or die "cannot write $out\n";
    open BAD, ">$exclude" or die "cannot write $exclude\n";
    warn "writing final sequences to $out\n" if (defined $verbose);
    warn "writing exclude sequences to $exclude\n" if (defined $verbose);
    foreach my $id (@ids) {
        my $lab = $data{$id}{'label'};
        $lab = $data{$id}{'newlabel'} if (defined $data{$id}{'newlabel'});
        my $seq = $data{$id}{'seq'};
        $seq = revcomp($seq) if ($data{$id}{'reverse'} == 1);
        if ($data{$id}{'delete'} == 1) {
            print BAD ">$lab\n$seq";
        }
        else {
            print OUT ">$lab\n$seq";
        }
    }
    close OUT;
    warn "Done.\n" if (defined $verbose);
}

sub loadRepClasses {
    warn "loading repeat families\n" if (defined $verbose);
    @classes = qw#
ARTEFACT
DNA
DNA/Academ
DNA/CMC-Chapaev
DNA/CMC-Chapaev-3
DNA/CMC-EnSpm
DNA/CMC-Mirage
DNA/CMC-Transib
DNA/Chapaev
DNA/Crypton
DNA/Ginger
DNA/Harbinger
DNA/Kolobok
DNA/Kolobok-Hydra
DNA/Kolobok-T2
DNA/MULE-F
DNA/MULE-MuDR
DNA/MULE-NOF
DNA/Maverick
DNA/Merlin
DNA/Novosib
DNA/P
DNA/P-Fungi
DNA/PIF-Harbinger
DNA/PIF-ISL2EU
DNA/PiggyBac
DNA/Sola
DNA/TcMar
DNA/TcMar-Ant1
DNA/TcMar-Fot1
DNA/TcMar-Gizmo
DNA/TcMar-ISRm11
DNA/TcMar-Mariner
DNA/TcMar-Mogwai
DNA/TcMar-Pogo
DNA/TcMar-Sagan
DNA/TcMar-Stowaway
DNA/TcMar-Tc1
DNA/TcMar-Tc2
DNA/TcMar-Tc4
DNA/TcMar-Tigger
DNA/TcMar-m44
DNA/Transib
DNA/Zator
DNA/Zisupton
DNA/hAT
DNA/hAT-Ac
DNA/hAT-Blackjack
DNA/hAT-Charlie
DNA/hAT-Pegasus
DNA/hAT-Restless
DNA/hAT-Tag1
DNA/hAT-Tip100
DNA/hAT-Tol2
DNA/hAT-hAT1
DNA/hAT-hAT5
DNA/hAT-hATm
DNA/hAT-hATw
DNA/hAT-hATx
DNA/hAT-hobo
LINE
LINE/Ambal
LINE/CR1
LINE/CR1-Zenon
LINE/CRE
LINE/DRE
LINE/Dong-R4
LINE/Genie
LINE/I
LINE/Jockey
LINE/L1
LINE/L1-Tx1
LINE/L2
LINE/L2-Hydra
LINE/LOA
LINE/Odin
LINE/Penelope
LINE/Proto1
LINE/Proto2
LINE/R1
LINE/R2
LINE/R2-Hero
LINE/RTE
LINE/RTE-BovB
LINE/RTE-RTE
LINE/RTE-X
LINE/Rex-Babar
LINE/Tad1
LINE/Zorro
LINE/telomeric
LTR
LTR/Caulimovirus
LTR/Copia
LTR/Copia(Xen1)
LTR/DIRS
LTR/ERV
LTR/ERV-Foamy
LTR/ERV-Lenti
LTR/ERV1
LTR/ERVK
LTR/ERVL
LTR/ERVL-MaLR
LTR/Gypsy
LTR/Gypsy-Troyka
LTR/Ngaro
LTR/Pao
LTR/TATE
LTR/Viper
Low_complexity
Other
Other/Composite
Other/DNA_virus
Other/centromeric
Other/subtelomeric
RC/Helitron
RNA
Retroposon
SINE
SINE/5S
SINE/7SL
SINE/Alu
SINE/B2
SINE/B4
SINE/BovA
SINE/C
SINE/CORE
SINE/Deu
SINE/Dong-R4
SINE/I
SINE/ID
SINE/L1
SINE/L2
SINE/MIR
SINE/Mermaid
SINE/R1
SINE/R2
SINE/RTE
SINE/RTE-BovB
SINE/Salmon
SINE/Sauria
SINE/V
SINE/tRNA
SINE/tRNA-7SL
SINE/tRNA-CR1
SINE/tRNA-Glu
SINE/tRNA-L2
SINE/tRNA-Lys
SINE/tRNA-R2
SINE/tRNA-RTE
Satellite
Satellite/W-chromosome
Satellite/Y-chromosome
Satellite/acromeric
Satellite/centromeric
Satellite/macro
Satellite/subtelomeric
Satellite/telomeric
Segmental
Simple_repeat
Unknown
Unknown/Y-chromosome
Unknown/centromeric
rRNA
scRNA
snRNA
tRNA
NoClass
#;
}
