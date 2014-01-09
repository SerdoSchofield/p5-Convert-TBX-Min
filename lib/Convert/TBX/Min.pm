package Convert::TBX::Min;
use strict;
use warnings;
use TBX::Min;
use XML::Writer;
use XML::Twig;
use Exporter::Easy (
	OK => ['min2basic']
);

# report parsing errors from TBX::Min in the caller's namespace,
# not ours
our @CARP_NOT = __PACKAGE__;

# VERSION

# ABSTRACT: Convert TBX-Min to TBX-Basic
=head1 SYNOPSIS

	use Convert::TBX::Min (min2basic);
	min2basic('/path/to/file'); # XML string pointer okay too

=head1 DESCRIPTION

This module converts TBX-Min XML into TBX-Basic XML.

=cut

min2basic(@ARGV) unless caller;

=head1 FUNCTIONS

=head2 C<min2basic>

Converts TBX-Min data into TBX-Basic data. The argument may be either
the path to a TBX-Min file, a scalar ref containing the actual
TBX-Min text, or a TBX::Min object. The return value is a scalar
ref containing the TBX-Basic data.

=cut

sub min2basic {
	my ($input) = @_;
	my $min;
	if(ref $input eq 'TBX::Min'){
		$min = $input;
	}else{
		my $min = TBX::Min->new_from_xml($input);
	}
	my $xml;
	my $martif = XML::Twig::Elt->new(martif => {type => 'TBX-Basic'});
    $martif->set_pretty_print('indented');
	if($min->source_lang){
		$martif->set_att('xml:lang' => $min->source_lang);
	}
    my $header = _make_header($min);
    $header->paste($martif);
    _make_text($min)->paste('after' => $header);

    my $twig = XML::Twig->new();
    $twig->set_doctype('martif', 'TBXBasiccoreStructV02.dtd');
    $twig->set_root($martif);
	return \$twig->sprint;
}

# create the martifHeader element from the TBX::Min input
sub _make_header {
    my ($min) = @_;
    my $header = XML::Twig::Elt->new('martifHeader');
    XML::Twig::Elt->new(p => {type => 'XCSURI'}, 'TBXBasicXCSV02.xcs')->
        wrap_in('encodingDesc')->paste($header);

    my $file_desc = XML::Twig::Elt->new('fileDesc');
    $file_desc->paste($header);
    XML::Twig::Elt->new(title => $min->id)->
        wrap_in('titleStmt')->paste($file_desc);

    my $source_desc = XML::Twig::Elt->new('sourceDesc')->
        paste($file_desc);

    my @header_atts;
    for my $header_att (qw(creator description directionality license)){
        no strict 'refs';
        if(my $value = $min->$header_att){
            push @header_atts, "$header_att: $value";
        }
    }
    if(@header_atts){
        for my $att(@header_atts){
            XML::Twig::Elt->new(p => $att)->paste($source_desc);
        }
    }
    # need a default source description
    if(not $min->description){
        XML::Twig::Elt->new(p => $min->id . ' (generated from UTX)')->
            paste($source_desc);
    }

    return $header;
}

# create the body element from the TBX::Min input
sub _make_text {
    my ($min) = @_;
    my $body = XML::Twig::Elt->new('body');

    for my $concept (@{$min->concepts}){
        my $entry = XML::Twig::Elt->new(
            'termEntry' => {id => $concept->id})->paste(
            last_child => $body);
        if(my $subject_field = $concept->subject_field){
            XML::Twig::Elt->new(descrip => {type => 'subjectField'},
                $subject_field)->paste($entry);
        }
        for my $lang_group (@{$concept->lang_groups}){
            my $lang_el = XML::Twig::Elt->new(
                langSet => {'xml:lang' => $lang_group->code})->
                paste($entry);
            for my $term_group (@{$lang_group->term_groups}){
                my $term_el = XML::Twig::Elt->new('tig');
                $term_el->paste($lang_el);
                XML::Twig::Elt->new(
                    term => $term_group->term)->paste($term_el);
                if(my $status = $term_group->status){
                    XML::Twig::Elt->new(termNote =>
                        {type => 'administrativeStatus'}, $status)->
                        paste($term_el);
                }
                if(my $customer = $term_group->customer){
                    XML::Twig::Elt->new(admin =>
                        {type => 'customerSubset'}, $customer)->
                        paste($term_el);
                }
                if(my $pos = $term_group->part_of_speech){
                    XML::Twig::Elt->new(termNote =>
                        {type => 'partOfSpeech'}, $pos)->
                        paste($term_el);
                }
                if(my $note = $term_group->note){
                    XML::Twig::Elt->new(admin => $note)->
                        paste($term_el);
                }
            }
        }
    }
    return $body->wrap_in('text');
}

1;