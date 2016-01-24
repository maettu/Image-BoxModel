package Image::BoxModel;	

use 5.006000;
use warnings;
use strict;
our $VERSION = '0.50';
use Carp;

use Image::BoxModel::Lowlevel;	#Lowlevel methods like boxes, text, graphic primitives
use Image::BoxModel::Text;		#Automatically makes a fitting box and puts text on it. Uses Lowlevel methods

our @ISA = ("Image::BoxModel::Text", "Image::BoxModel::Lowlevel");

sub new{
	my $class = shift;
	
	#Define a new image an preset some values before..
	my $image ={
		width => 400, 
		height => 300,
		background => 'white',
		lib=> 'GD',	#IM or GD ;-)
		PI => 3.14159265358979,
		verbose => "0",	#if we print many messages about what the programs do.
		#.. adding the users parameters
		@_
	};
	$image->{height}--;	#Because a picture of 400 pixels height ranges from 0-399
	$image->{width}--;
		
	$image->{free} = {	#This is the standard-box. It will shrink when a new box is added. Now it fills the whole background.
		top => 0,
		bottom => $image->{height},
		height => $image -> {height},
		left => 0,
		right => $image->{width},
		width => $image->{width}
	};
	
	# The preset Colors (see below are read in). This is not done with DATA on purpose. 
	# I had some strange errors when using Image::BoxModel while open Filehandles in calling programs
	%{$image->{preset_colors}} = PresetColors();
		
	#Now follow the definitions of the backend-libraries
	#Inheritance is granted by using the appropriate backend-modules.
	#This means that if GD is used, then the image-object has ::Backend::GD as its parent, so therefore the appropriate methods in ::Backend::GD are found.
	#I don't know if this is good software design..
	
	if ($image -> {lib} eq "IM"){
		require Image::Magick;
		require Image::BoxModel::Backend::IM;
		push @ISA, "Image::BoxModel::Backend::IM";
		
		$image->{IM} = new Image::Magick; 
		$image->{IM} -> Set(size => ($image->{width}+1)."x".($image->{height}+1)); #IM calculates "human-style" 800x400 is from 0 to 799 and 0 to 399 :-) we do width-- and height-- because we don't do human style in this module.
		$image->{IM} -> Read("xc:$image->{background}"); 
	}
	elsif ($image -> {lib} eq "GD"){
		require GD;
		require Image::BoxModel::Backend::GD;
		push @ISA, "Image::BoxModel::Backend::GD";
		
		
		$image->{GD} = new GD::Image($image->{width}+1,$image->{height}+1);
		$image->{colors}{'#ffffff'} = $image->{GD}->colorAllocate(255,255,255);	#allocate white to ensure white background. This is perhaps not a clever move, but otherwise it will be drawn with the first color allocated, which quite surely is seldom desired.
		
		#Fontconfig should not be enabled by default, even it is tempting to do so ;-). The examples will presumably produce many errors if fontconfig can't be enabled.
		
		if (exists $image->{fontconfig} and $image->{fontconfig} != 0){
			my $a = $image->{GD}->useFontConfig(1);
			if ($a == 0){
				print "Fontconfig not available!";
				$image->{fontconfig} = 0;	#to get(!) errors later on. If loading fails, then we don't want to pretend we loaded it.
			}
		}
		else{
			$image->{fontconfig} = 0;	#to avoid silly "uninitialized value"-errors later on
		}
	}
	
	bless $image, $class;
		
	return $image;
}

1;

=head1 NAME

Image::BoxModel - Module for defining boxes on an image and putting things on them

=head1 SYNOPSIS

 use Image::BoxModel;
  
 #Define an object
 my  $image = new Image::BoxModel (
	width 	=> 800, 
	height	=> 400, 
	lib		=> 'GD', 			#[IM|GD]
	precise => '1'		#IM only: IM-backend will draw antialiased lines instead of rounding to integers before drawing.
						#I don't know, if this is of interest to anyone..
	verbose => '1',		#If you want to see which modules and submodules do what. 
						#Be prepared to see many messages :-)
 );
				
 #Define a box named "title" on the upper border
 print $image -> Box(position =>"top", height=>120, name=>"title", background =>'red');	
 
 #Put some rotated text on the "title"-box and demonstrate some options. 
 #(verdana.ttf needs to be present in the same directory)
 print $image -> Text(
	box 	=> "title", 
	text	=>"Hello World!\nAligned right, positioned in the center (default)\nslightly rotated.", 
	textsize=>"16",
	rotate 	=> "10" , 
	font	=> './FreeSans.ttf', #must be present in the same directory. See PORTABILITY below.
	fill 	=> "yellow", 
	background=>"green", 
	align	=>"Right"
 );
 
 print $image -> Box(position =>"left", width=>200, name=>"text_1", background =>'blue');	
 print $image -> Text(
	box 		=> "text_1", text =>"Some 'North-West'-aligned text.\n:-)", 
	textsize	=> "12", 
	background	=>"yellow", 
	position 	=>"NorthWest"
 );
 
 print $image -> Text(text => "Some more text on the free space.",textsize => 12, rotate=> "-30");
 
 #Save image to file
 $image -> Save(file=> "01_hello_world_$image->{lib}.png");

More examples are in examples/

=head1 DESCRIPTION

=head2 OBJECTIVES

Have a way to draw things on images using the same code with different libraries.

Use OO-style design to make the implementation of new library backends (library wrappers) easy. Image::Magick and GD present at the moment.

Use a box model to cut the original image into smaller rectangles. Afterwards objects can be drawn onto these boxes.

=head2 ANOTHER IMAGING / CHARTING / WHATEVER MODULE?

There are many Charting Modules and many Font Modules as well. 
There are many concepts about how to layout elements on an image / page.

This module will try hard to make the life of the user easier and the life of the developer more fun.

It has backends for graphic libraries so that you can draw images using the same code with different libraries.

Example: One user (me ;-) starts writing a perl script which produces some charts. 
Because Image::Magick is common to me, I use it. After some time I find out that GD would be much faster and is able to do everything I need.
I have to rewrite much of my code because GD does many things different from how IM does them.
..And now someone tells me about the Imager-module from the CPAN!

With this module it is (should be) possible to just replace $image->{lib} in the constructor method and keep the rest of the code.

=head2 PORTABILITY

If you want to write portable code, you have to stick with the following things: (Portability between OSes and between backend libs)

=head3 Don't use fontconfig

You can profit from the wonderful possibilties offered by fontconfig, if you use this module on a system with fontconfig and GD as backend lib. 
Anyhow, if you change the backend to Image::Magick later or take your code to a system without fontconfig, it will produce errors.

Perhaps these considerations will lead to removing fontconfig support from Image::BoxModel. Perhaps 'font' will be mandatory for 'Text' and 'Annotate'. 
Perhaps there will be a possibilty to specify a default font. 

=head3 Copy the font files into your projects directory tree

There is never a guarantee that fonts are present on a different system or on a different machine. You don't know if they are in the same place.

=head3 Always use the 'font' parameter with 'Text' and 'Annotate'

To be safe that the font is found (or an error is displayed), use

 font=>'path/to/my/font.ttf'

as a parameter with every 'Text' or 'Annotate' call.

Of course, it is much more conventient to rely on the default settings of fontconfig or some libraries internal magic, but it beaks portability very easily.

=head3 Don't use absolute paths

Yes, of course not. ;-)

It is tempting to use absolute paths to find fonts. Don't. Don't repeat my mistakes. :-)

=head3 Don't use library-methods

It is possible to use every method of the chosen library through the objects library-object:

$image->{IM} -> Edge(radius => "10");

This of course only works with Image::Magick. First, because there will be no {IM} if using GD und second, because GD doesn't know about 'Edge'.
On the other hand, this code will only work with GD:

 $image->{GD} -> arc(50,50,95,75,0,360,$image->Colors(color=>'blue'));

There may be cases in which you will want to use library-specific code. Image::BoxModel doesn't implement all features of all libraries. Besides, this would be quite difficult. 

=head2 FUTURE

Charts: being done

More graphic primitives

Vector graphic backend
(The problem is, the module "thinks" in bitmaps, so it is not completely clear to me how to transfer this into vectors..)

Imager backend

Any more ideas?

=head2 QUESTIONS

Would it make sense to be able and cut off nonrectangular boxes? / Would it be desirable to cut off boxes which result in a nonrectangular remaining free space?
(Define a rectangle in the upper left corner. Then the free field would be a concave hexagon. This produces some problems later: defining new boxes / find out if object is in the box)

How to translate the used bitmap model into the vector model? 
In the bitmap model the smallest unit is one pixel, which defines rather a area of the image with a certain size.
In the world of vectors there is no smallest unit (is there?) and a point has no size.


=head2 EXAMPLES

There is a growing set of sample programs in the examples/ directory together with their respective images. 
This should allow you to understand how things work and verify if your copy of the module works as expected.
To ensure they work even if you don't install the module into your system, they use a "use lib ("../lib"); Dunno if this is appropriate.

=head2 SEE:

README for installation & dependencies

L<Image::BoxModel::Lowlevel> - basic functionality

L<Image::BoxModel::Text> - direct and save drawing of text

L<Image::BoxModel::Chart> - charts (incomplete)

L<Image::BoxModel::Color> - mini-tutorial on how to use colors

=head1 BUGS

oh, please ;-)

Bug reports are welcome.

=head1 AUTHOR

Matthias Bloch, <lt>matthias at puffin ch<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by :m)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut


#~ __DATA__
sub PresetColors{
	my $colors_text = '#FFFAFA	snow
#FFFAFA	snow1
#EEE9E9	snow2
#FFC1C1	RosyBrown1
#EEB4B4	RosyBrown2
#CDC9C9	snow3
#F08080	LightCoral
#FF6A6A	IndianRed1
#CD9B9B	RosyBrown3
#EE6363	IndianRed2
#BC8F8F	RosyBrown
#FF4040	brown1
#FF3030	firebrick1
#EE3B3B	brown2
#CD5C5C	IndianRed
#CD5555	IndianRed3
#EE2C2C	firebrick2
#8B8989	snow4
#CD3333	brown3
#FF0000	red
#FF0000	red1
#8B6969	RosyBrown4
#CD2626	firebrick3
#EE0000	red2
#B22222	firebrick
#A52A2A	brown
#CD0000	red3
#8B3A3A	IndianRed4
#8B2323	brown4
#8B1A1A	firebrick4
#8B0000	DarkRed
#8B0000	red4
#800000	maroon
#FFAEB9	LightPink1
#CD8C95	LightPink3
#8B5F65	LightPink4
#EEA2AD	LightPink2
#FFB6C1	LightPink
#FFC0CB	pink
#DC143C	crimson
#FFB5C5	pink1
#EEA9B8	pink2
#CD919E	pink3
#8B636C	pink4
#8B475D	PaleVioletRed4
#DB7093	PaleVioletRed
#EE799F	PaleVioletRed2
#FF82AB	PaleVioletRed1
#CD6889	PaleVioletRed3
#FFF0F5	LavenderBlush
#FFF0F5	LavenderBlush1
#CDC1C5	LavenderBlush3
#EEE0E5	LavenderBlush2
#8B8386	LavenderBlush4
#B03060	maroon
#CD6090	HotPink3
#CD3278	VioletRed3
#FF3E96	VioletRed1
#EE3A8C	VioletRed2
#8B2252	VioletRed4
#EE6AA7	HotPink2
#FF6EB4	HotPink1
#8B3A62	HotPink4
#FF69B4	HotPink
#FF1493	DeepPink
#FF1493	DeepPink1
#EE1289	DeepPink2
#CD1076	DeepPink3
#8B0A50	DeepPink4
#FF34B3	maroon1
#EE30A7	maroon2
#CD2990	maroon3
#8B1C62	maroon4
#C71585	MediumVioletRed
#D02090	VioletRed
#EE7AE9	orchid2
#DA70D6	orchid
#FF83FA	orchid1
#CD69C9	orchid3
#8B4789	orchid4
#FFE1FF	thistle1
#EED2EE	thistle2
#FFBBFF	plum1
#EEAEEE	plum2
#D8BFD8	thistle
#CDB5CD	thistle3
#DDA0DD	plum
#EE82EE	violet
#CD96CD	plum3
#8B7B8B	thistle4
#FF00FF	fuchsia
#FF00FF	magenta
#FF00FF	magenta1
#8B668B	plum4
#EE00EE	magenta2
#CD00CD	magenta3
#8B008B	DarkMagenta
#8B008B	magenta4
#800080	purple
#BA55D3	MediumOrchid
#E066FF	MediumOrchid1
#D15FEE	MediumOrchid2
#B452CD	MediumOrchid3
#7A378B	MediumOrchid4
#9400D3	DarkViolet
#9932CC	DarkOrchid
#BF3EFF	DarkOrchid1
#9A32CD	DarkOrchid3
#B23AEE	DarkOrchid2
#68228B	DarkOrchid4
#A020F0	purple
#4B0082	indigo
#8A2BE2	BlueViolet
#912CEE	purple2
#7D26CD	purple3
#551A8B	purple4
#9B30FF	purple1
#9370DB	MediumPurple
#AB82FF	MediumPurple1
#9F79EE	MediumPurple2
#8968CD	MediumPurple3
#5D478B	MediumPurple4
#483D8B	DarkSlateBlue
#8470FF	LightSlateBlue
#7B68EE	MediumSlateBlue
#6A5ACD	SlateBlue
#836FFF	SlateBlue1
#7A67EE	SlateBlue2
#6959CD	SlateBlue3
#473C8B	SlateBlue4
#F8F8FF	GhostWhite
#E6E6FA	lavender
#0000FF	blue
#0000FF	blue1
#0000EE	blue2
#0000CD	blue3
#0000CD	MediumBlue
#00008B	blue4
#00008B	DarkBlue
#191970	MidnightBlue
#000080	navy
#000080	NavyBlue
#4169E1	RoyalBlue
#4876FF	RoyalBlue1
#436EEE	RoyalBlue2
#3A5FCD	RoyalBlue3
#27408B	RoyalBlue4
#6495ED	CornflowerBlue
#B0C4DE	LightSteelBlue
#CAE1FF	LightSteelBlue1
#BCD2EE	LightSteelBlue2
#A2B5CD	LightSteelBlue3
#6E7B8B	LightSteelBlue4
#6C7B8B	SlateGray4
#C6E2FF	SlateGray1
#B9D3EE	SlateGray2
#9FB6CD	SlateGray3
#778899	LightSlateGray
#778899	LightSlateGrey
#708090	SlateGray
#708090	SlateGrey
#1E90FF	DodgerBlue
#1E90FF	DodgerBlue1
#1C86EE	DodgerBlue2
#104E8B	DodgerBlue4
#1874CD	DodgerBlue3
#F0F8FF	AliceBlue
#36648B	SteelBlue4
#4682B4	SteelBlue
#63B8FF	SteelBlue1
#5CACEE	SteelBlue2
#4F94CD	SteelBlue3
#4A708B	SkyBlue4
#87CEFF	SkyBlue1
#7EC0EE	SkyBlue2
#6CA6CD	SkyBlue3
#87CEFA	LightSkyBlue
#607B8B	LightSkyBlue4
#B0E2FF	LightSkyBlue1
#A4D3EE	LightSkyBlue2
#8DB6CD	LightSkyBlue3
#87CEEB	SkyBlue
#9AC0CD	LightBlue3
#00BFFF	DeepSkyBlue
#00BFFF	DeepSkyBlue1
#00B2EE	DeepSkyBlue2
#00688B	DeepSkyBlue4
#009ACD	DeepSkyBlue3
#BFEFFF	LightBlue1
#B2DFEE	LightBlue2
#ADD8E6	LightBlue
#68838B	LightBlue4
#B0E0E6	PowderBlue
#98F5FF	CadetBlue1
#8EE5EE	CadetBlue2
#7AC5CD	CadetBlue3
#53868B	CadetBlue4
#00F5FF	turquoise1
#00E5EE	turquoise2
#00C5CD	turquoise3
#00868B	turquoise4
#5F9EA0	cadet blue
#5F9EA0	CadetBlue
#00CED1	DarkTurquoise
#F0FFFF	azure
#F0FFFF	azure1
#E0FFFF	LightCyan
#E0FFFF	LightCyan1
#E0EEEE	azure2
#D1EEEE	LightCyan2
#BBFFFF	PaleTurquoise1
#AFEEEE	PaleTurquoise
#AEEEEE	PaleTurquoise2
#97FFFF	DarkSlateGray1
#C1CDCD	azure3
#B4CDCD	LightCyan3
#8DEEEE	DarkSlateGray2
#96CDCD	PaleTurquoise3
#79CDCD	DarkSlateGray3
#838B8B	azure4
#7A8B8B	LightCyan4
#00FFFF	aqua
#00FFFF	cyan
#00FFFF	cyan1
#668B8B	PaleTurquoise4
#00EEEE	cyan2
#528B8B	DarkSlateGray4
#00CDCD	cyan3
#008B8B	cyan4
#008B8B	DarkCyan
#008080	teal
#2F4F4F	DarkSlateGray
#2F4F4F	DarkSlateGrey
#48D1CC	MediumTurquoise
#20B2AA	LightSeaGreen
#40E0D0	turquoise
#458B74	aquamarine4
#7FFFD4	aquamarine
#7FFFD4	aquamarine1
#76EEC6	aquamarine2
#66CDAA	aquamarine3
#66CDAA	MediumAquamarine
#00FA9A	MediumSpringGreen
#F5FFFA	MintCream
#00FF7F	SpringGreen
#00FF7F	SpringGreen1
#00EE76	SpringGreen2
#00CD66	SpringGreen3
#008B45	SpringGreen4
#3CB371	MediumSeaGreen
#2E8B57	SeaGreen
#43CD80	SeaGreen3
#54FF9F	SeaGreen1
#2E8B57	SeaGreen4
#4EEE94	SeaGreen2
#32814B	MediumForestGreen
#F0FFF0	honeydew
#F0FFF0	honeydew1
#E0EEE0	honeydew2
#C1FFC1	DarkSeaGreen1
#B4EEB4	DarkSeaGreen2
#9AFF9A	PaleGreen1
#98FB98	PaleGreen
#C1CDC1	honeydew3
#90EE90	LightGreen
#90EE90	PaleGreen2
#9BCD9B	DarkSeaGreen3
#8FBC8F	DarkSeaGreen
#7CCD7C	PaleGreen3
#838B83	honeydew4
#00FF00	green1
#00FF00	lime
#32CD32	LimeGreen
#698B69	DarkSeaGreen4
#00EE00	green2
#548B54	PaleGreen4
#00CD00	green3
#228B22	ForestGreen
#008B00	green4
#008000	green
#006400	DarkGreen
#7CFC00	LawnGreen
#7FFF00	chartreuse
#7FFF00	chartreuse1
#76EE00	chartreuse2
#66CD00	chartreuse3
#458B00	chartreuse4
#ADFF2F	GreenYellow
#A2CD5A	DarkOliveGreen3
#CAFF70	DarkOliveGreen1
#BCEE68	DarkOliveGreen2
#6E8B3D	DarkOliveGreen4
#556B2F	DarkOliveGreen
#6B8E23	OliveDrab
#C0FF3E	OliveDrab1
#B3EE3A	OliveDrab2
#9ACD32	OliveDrab3
#9ACD32	YellowGreen
#698B22	OliveDrab4
#FFFFF0	ivory
#FFFFF0	ivory1
#FFFFE0	LightYellow
#FFFFE0	LightYellow1
#F5F5DC	beige
#EEEEE0	ivory2
#FAFAD2	LightGoldenrodYellow
#EEEED1	LightYellow2
#CDCDC1	ivory3
#CDCDB4	LightYellow3
#8B8B83	ivory4
#8B8B7A	LightYellow4
#FFFF00	yellow
#FFFF00	yellow1
#EEEE00	yellow2
#CDCD00	yellow3
#8B8B00	yellow4
#808000	olive
#BDB76B	DarkKhaki
#EEE685	khaki2
#8B8970	LemonChiffon4
#FFF68F	khaki1
#CDC673	khaki3
#8B864E	khaki4
#EEE8AA	PaleGoldenrod
#FFFACD	LemonChiffon
#FFFACD	LemonChiffon1
#F0E68C	khaki
#CDC9A5	LemonChiffon3
#EEE9BF	LemonChiffon2
#D1C166	MediumGoldenRod
#8B8878	cornsilk4
#FFD700	gold
#FFD700	gold1
#EEC900	gold2
#CDAD00	gold3
#8B7500	gold4
#EEDD82	LightGoldenrod
#8B814C	LightGoldenrod4
#FFEC8B	LightGoldenrod1
#CDBE70	LightGoldenrod3
#EEDC82	LightGoldenrod2
#CDC8B1	cornsilk3
#EEE8CD	cornsilk2
#FFF8DC	cornsilk
#FFF8DC	cornsilk1
#DAA520	goldenrod
#FFC125	goldenrod1
#EEB422	goldenrod2
#CD9B1D	goldenrod3
#8B6914	goldenrod4
#B8860B	DarkGoldenrod
#FFB90F	DarkGoldenrod1
#EEAD0E	DarkGoldenrod2
#CD950C	DarkGoldenrod3
#8B6508	DarkGoldenrod4
#FFFAF0	FloralWhite
#EED8AE	wheat2
#FDF5E6	OldLace
#F5DEB3	wheat
#FFE7BA	wheat1
#CDBA96	wheat3
#FFA500	orange
#FFA500	orange1
#EE9A00	orange2
#CD8500	orange3
#8B5A00	orange4
#8B7E66	wheat4
#FFE4B5	moccasin
#FFEFD5	PapayaWhip
#CDB38B	NavajoWhite3
#FFEBCD	BlanchedAlmond
#FFDEAD	NavajoWhite
#FFDEAD	NavajoWhite1
#EECFA1	NavajoWhite2
#8B795E	NavajoWhite4
#8B8378	AntiqueWhite4
#FAEBD7	AntiqueWhite
#D2B48C	tan
#8B7D6B	bisque4
#DEB887	burlywood
#EEDFCC	AntiqueWhite2
#FFD39B	burlywood1
#CDAA7D	burlywood3
#EEC591	burlywood2
#FFEFDB	AntiqueWhite1
#8B7355	burlywood4
#CDC0B0	AntiqueWhite3
#FF8C00	DarkOrange
#EED5B7	bisque2
#FFE4C4	bisque
#FFE4C4	bisque1
#CDB79E	bisque3
#FF7F00	DarkOrange1
#FAF0E6	linen
#EE7600	DarkOrange2
#CD6600	DarkOrange3
#8B4500	DarkOrange4
#CD853F	peru
#FFA54F	tan1
#EE9A49	tan2
#CD853F	tan3
#8B5A2B	tan4
#FFDAB9	PeachPuff
#FFDAB9	PeachPuff1
#8B7765	PeachPuff4
#EECBAD	PeachPuff2
#CDAF95	PeachPuff3
#F4A460	SandyBrown
#8B8682	seashell4
#EEE5DE	seashell2
#CDC5BF	seashell3
#D2691E	chocolate
#FF7F24	chocolate1
#EE7621	chocolate2
#CD661D	chocolate3
#8B4513	chocolate4
#8B4513	SaddleBrown
#FFF5EE	seashell
#FFF5EE	seashell1
#8B4726	sienna4
#A0522D	sienna
#FF8247	sienna1
#EE7942	sienna2
#CD6839	sienna3
#CD8162	LightSalmon3
#FFA07A	LightSalmon
#FFA07A	LightSalmon1
#8B5742	LightSalmon4
#EE9572	LightSalmon2
#FF7F50	coral
#FF4500	OrangeRed
#FF4500	OrangeRed1
#EE4000	OrangeRed2
#CD3700	OrangeRed3
#8B2500	OrangeRed4
#E9967A	DarkSalmon
#FF8C69	salmon1
#EE8262	salmon2
#CD7054	salmon3
#8B4C39	salmon4
#FF7256	coral1
#EE6A50	coral2
#CD5B45	coral3
#8B3E2F	coral4
#8B3626	tomato4
#FF6347	tomato
#FF6347	tomato1
#EE5C42	tomato2
#CD4F39	tomato3
#8B7D7B	MistyRose4
#EED5D2	MistyRose2
#FFE4E1	MistyRose
#FFE4E1	MistyRose1
#FA8072	salmon
#CDB7B5	MistyRose3
#FFFFFF	white
#FFFFFF	gray100
#FFFFFF	grey100
#FFFFFF	grey100
#FCFCFC	gray99
#FCFCFC	grey99
#FAFAFA	gray98
#FAFAFA	grey98
#F7F7F7	gray97
#F7F7F7	grey97
#F5F5F5	gray96
#F5F5F5	grey96
#F5F5F5	WhiteSmoke
#F2F2F2	gray95
#F2F2F2	grey95
#F0F0F0	gray94
#F0F0F0	grey94
#EDEDED	gray93
#EDEDED	grey93
#EBEBEB	gray92
#EBEBEB	grey92
#E8E8E8	gray91
#E8E8E8	grey91
#E5E5E5	gray90
#E5E5E5	grey90
#E3E3E3	gray89
#E3E3E3	grey89
#E0E0E0	gray88
#E0E0E0	grey88
#DEDEDE	gray87
#DEDEDE	grey87
#DCDCDC	gainsboro
#DBDBDB	gray86
#DBDBDB	grey86
#D9D9D9	gray85
#D9D9D9	grey85
#D6D6D6	gray84
#D6D6D6	grey84
#D4D4D4	gray83
#D4D4D4	grey83
#D3D3D3	LightGray
#D3D3D3	LightGrey
#D1D1D1	gray82
#D1D1D1	grey82
#CFCFCF	gray81
#CFCFCF	grey81
#CCCCCC	gray80
#CCCCCC	grey80
#C9C9C9	gray79
#C9C9C9	grey79
#C7C7C7	gray78
#C7C7C7	grey78
#C4C4C4	gray77
#C4C4C4	grey77
#C2C2C2	gray76
#C2C2C2	grey76
#C0C0C0	silver
#BFBFBF	gray75
#BFBFBF	grey75
#BEBEBE	gray
#BEBEBE	grey
#BDBDBD	gray74
#BDBDBD	grey74
#BABABA	gray73
#BABABA	grey73
#B8B8B8	gray72
#B8B8B8	grey72
#B5B5B5	gray71
#B5B5B5	grey71
#B3B3B3	gray70
#B3B3B3	grey70
#B0B0B0	gray69
#B0B0B0	grey69
#ADADAD	gray68
#ADADAD	grey68
#ABABAB	gray67
#ABABAB	grey67
#A9A9A9	DarkGray
#A9A9A9	DarkGrey
#A8A8A8	gray66
#A8A8A8	grey66
#A6A6A6	gray65
#A6A6A6	grey65
#A3A3A3	gray64
#A3A3A3	grey64
#A1A1A1	gray63
#A1A1A1	grey63
#9E9E9E	gray62
#9E9E9E	grey62
#9C9C9C	gray61
#9C9C9C	grey61
#999999	gray60
#999999	grey60
#969696	gray59
#969696	grey59
#949494	gray58
#949494	grey58
#919191	gray57
#919191	grey57
#8F8F8F	gray56
#8F8F8F	grey56
#8C8C8C	gray55
#8C8C8C	grey55
#8A8A8A	gray54
#8A8A8A	grey54
#878787	gray53
#878787	grey53
#858585	gray52
#858585	grey52
#828282	gray51
#828282	grey51
#808080	fractal
#7F7F7F	gray50
#7F7F7F	grey50
#7E7E7E	gray
#7D7D7D	gray49
#7D7D7D	grey49
#7A7A7A	gray48
#7A7A7A	grey48
#787878	gray47
#787878	grey47
#757575	gray46
#757575	grey46
#737373	gray45
#737373	grey45
#707070	gray44
#707070	grey44
#6E6E6E	gray43
#6E6E6E	grey43
#6B6B6B	gray42
#6B6B6B	grey42
#696969	DimGray
#696969	DimGrey
#696969	gray41
#696969	grey41
#666666	gray40
#666666	grey40
#636363	gray39
#636363	grey39
#616161	gray38
#616161	grey38
#5E5E5E	gray37
#5E5E5E	grey37
#5C5C5C	gray36
#5C5C5C	grey36
#595959	gray35
#595959	grey35
#575757	gray34
#575757	grey34
#545454	gray33
#545454	grey33
#525252	gray32
#525252	grey32
#4F4F4F	gray31
#4F4F4F	grey31
#4D4D4D	gray30
#4D4D4D	grey30
#4A4A4A	gray29
#4A4A4A	grey29
#474747	gray28
#474747	grey28
#454545	gray27
#454545	grey27
#424242	gray26
#424242	grey26
#404040	gray25
#404040	grey25
#3D3D3D	gray24
#3D3D3D	grey24
#3B3B3B	gray23
#3B3B3B	grey23
#383838	gray22
#383838	grey22
#363636	gray21
#363636	grey21
#333333	gray20
#333333	grey20
#303030	gray19
#303030	grey19
#2E2E2E	gray18
#2E2E2E	grey18
#2B2B2B	gray17
#2B2B2B	grey17
#292929	gray16
#292929	grey16
#262626	gray15
#262626	grey15
#242424	gray14
#242424	grey14
#212121	gray13
#212121	grey13
#1F1F1F	gray12
#1F1F1F	grey12
#1C1C1C	gray11
#1C1C1C	grey11
#1A1A1A	gray10
#1A1A1A	grey10
#171717	gray9
#171717	grey9
#141414	gray8
#141414	grey8
#121212	gray7
#121212	grey7
#0F0F0F	gray6
#0F0F0F	grey6
#0D0D0D	gray5
#0D0D0D	grey5
#0A0A0A	gray4
#0A0A0A	grey4
#080808	gray3
#080808	grey3
#050505	gray2
#050505	grey2
#030303	gray1
#030303	grey1
#000000	black
#000000	gray0
#000000	grey0
#000000	opaque';

my @lines = split (/\n/, $colors_text);
my %colors;
 foreach (@lines){	#load all known color names into $image->{preset_colors}
		chomp;
		my ($html, $human_name) = split(/\t/,$_);
		$colors{$human_name} = $html;
		#~ #print $image -> {preset_colors}{$human_name} ,"-> $human_name\n"
	}
	
	#~ print foreach sort keys %colors;
return %colors;
}