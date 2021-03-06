#! /usr/bin/perl

# Either let us guess a suitable scale skip or pass it as a parameter..
# Here you can see how this is done and how we expand the scale to the next grid, if necessary.

use lib ("../lib");	#if you don't install the module but just untar & run example

use strict;
use warnings;


use Image::BoxModel::Chart;

my $image = new Image::BoxModel::Chart (
	width => 800, 
	height => 400, 
	lib=> "GD", 			# [IM|GD]
	verbose =>0,
	background => 'white',
	@ARGV			# used to automate via run_all_examples.pl
					# If you pass arguments directly from the command line be aware that there is no error-checking!
);	

$image -> BoxSplit (
	box 				=> 'free', 	# 'free' is the default box
	orientation			=> 'horizontal', 
	number 				=> 3,
	background_colors 	=> ['grey80', 'grey70', 'grey50'],
);

my @scale_skip = (1, 2, 3.5);
my @style  = ('bar', 'point', 'line');

foreach my $row (0 .. 2){
	
	# padding on the right side of the chart
	$image -> Box(
		resize 		=> "free_$row",
		position	=> 'right',
		width		=> 10,
		name 		=> "free_${row}_padding_right",
		background 	=> $image -> {background}
	);

	# title
	$image -> Annotate(
		resize	 	=> "free_$row",
		text 		=> "Scale skip $scale_skip[$row]",
		textsize 	=> 20,
		padding_bottom => 10,
	);
	
	$image -> BoxSplit (
		box			=> "free_$row",
		orientation	=> 'vertical',
		number		=> 3,
	);
	
	for my $col (0 .. 2){
		$image -> Box(
			resize		=> "free_${row}_$col",
			position	=> 'bottom',
			height		=> 10,
			name		=> "free_${row}_${col}_padding_bottom",
		);

		$image -> Chart (
			box 		=> "free_${row}_$col",
			dataset_1 	=> [5,4,0,3,6,4,3],
			scale_skip 	=> $scale_skip[$row],
			style 		=> $style[$col],
			thickness	=> 6,
			values_annotations => ['a','b','c', 'd', 'e', 'f', 'g'],
		);
	}
}

(my $name = $0) =~ s/\.pl$//;
$image -> Save(file=> $name."_$image->{lib}.png");

