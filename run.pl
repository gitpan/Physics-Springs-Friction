#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use Physics::Springs::Friction;
use Math::Project3D::Plot;
use Time::HiRes qw/time/;

my $sim = Physics::Springs::Friction->new();

my @p; # particles

$p[0] = $sim->add_particle(
  x  => -2,  y  => 0, z  => 0,
  vx => 0,  vy => 0.00001,  vz => 0,
  m  => 10000000000,  n  => 'Wall1',
);

$p[1] = $sim->add_particle(
  x  => -1,  y  => 0, z  =>  0,
  vx => 0,  vy => 0.10,  vz => -0.1,
  m  => 100,  n  => 'Particle1',
);

$p[2] = $sim->add_particle(
  x  => 0,  y  => 0, z  => 0,
  vx => 0,  vy => -0.10,  vz => 0.1,
  m  => 100,  n  => 'Particle2',
);

$p[3] = $sim->add_particle(
  x  => 1,  y  => 0, z  =>  0,
  vx => 0,  vy => 0.00001,  vz => 0,
  m  => 10000000000,  n  => 'Wall2',
);

# Springs
$sim->add_spring(k => 8, p1 => $p[0], p2 => $p[1], l => 1 );
$sim->add_spring(k => 8, p1 => $p[1], p2 => $p[2], l => 1 );
$sim->add_spring(k => 8, p1 => $p[2], p2 => $p[3], l => 1 );

# Friction-like forces
$sim->add_friction('stokes', .0002);

# Particle interaction forces

# Simulation settings

my $iterations          = 5000000;# Simulation length in iterations
my $per_sim_step        = 10000;  # Drawing interval (~10000)
my $time_diff_per_iter  = 0.00001;# "simulation accuracy"
my $iterations_per_line = 200;    # "inverse drawing accuracy"
my $snapshot_interval   = 10;      # Write image snapshot every n sim steps
my $outfile_basename    = 'p';    # Basename of output file
my $outfile_extension   = '.png'; # Extension of output file including '.'
my $new_file            = 1;      # Write snapshots to new files (tXXX.png)?
my $zoom                = 600;

my $simulation_steps = int( $iterations / $per_sim_step );
my $cur_iter  = 0;
my $snapshots = 1+ int($simulation_steps / $snapshot_interval);
my $variable_filename_length = length($snapshots);
my $snapshot_no = 0;

my @pos;
push @pos, [] foreach @p;

# Image/projection settings
my $img = Imager->new(xsize=>1024,ysize=>768);

my $proj = Math::Project3D->new(
   plane_basis_vector => [ 0, 0, 0 ],
   plane_direction1   => [ 0.371391, 0.928477, 0 ],
   plane_direction2   => [ 0.371391, 0, 0.928477 ],
);

$proj->new_function(
  sub { $pos[$_[0]][$_[1]][0] },
  sub { $pos[$_[0]][$_[1]][1] },
  sub { $pos[$_[0]][$_[1]][2] },
);

my @color;

push @color, Imager::Color->new( 255, 255, 0   ); # sun
push @color, Imager::Color->new( 0,   255, 0   ); # mercury
push @color, Imager::Color->new( 255, 0,   255 ); # venus
push @color, Imager::Color->new( 0,   0,   255 ); # earth
push @color, Imager::Color->new( 255, 255, 255 ); # moon
push @color, Imager::Color->new( 255, 0,   0   ); # mars

my $x_axis     = Imager::Color->new(40, 40, 40);
my $y_axis     = Imager::Color->new(40, 40, 40);
my $z_axis     = Imager::Color->new(40, 40, 40);
my $background = Imager::Color->new(0,   0, 0);

$img->flood_fill(x=>0,y=>0,color=>$background);

my $plotter = Math::Project3D::Plot->new(
  image      => $img,
  projection => $proj,
  scale      => $zoom,
);

$plotter->plot_axis( # x axis
  vector => [1, 0, 0],
  color  => $x_axis,
  length => 100,
);

$plotter->plot_axis( # y axis
  vector => [0, 1, 0],
  color  => $y_axis,
  length => 100,
);

$plotter->plot_axis( # z axis
  vector => [0, 0, 1],
  color  => $z_axis,
  length => 100,
);

my @times;
push @times, time();

foreach my $sim_step (1..$simulation_steps) {
	print "Simulation step $sim_step.\n";
	foreach ($cur_iter..($cur_iter+$per_sim_step)) {
	   print "Iteration $_.\n" unless $_ % 1000;
	   my $p_no = 0;
	   foreach my $p (@{ $sim->{p} }) {
	     push @{$pos[$p_no++]}, [ $p->{x}, $p->{y}, $p->{z} ];
	   }
	   $sim->iterate_step($time_diff_per_iter);
	}

	foreach (0..$#pos) {
	   $plotter->plot_range(
	     color  => $color[$_ % @color],
	     params => [
	                 [$_],
	                 [0, $per_sim_step-1, $iterations_per_line],
	               ],
	     type   => 'line',
	   );
	}
	my @last = @pos;
	@pos = ();
	my $count = 0;
	push @pos, [$last[$count++][-1]] foreach @p;
	$cur_iter += $per_sim_step;

	unless ($sim_step % $snapshot_interval) {
		print "Writing snapshot $snapshot_no.\n";
		my $filename = $outfile_basename . 
				($new_file ?
					sprintf(
					"\%0${variable_filename_length}i",
					$snapshot_no)
					: ''
				) .
				$outfile_extension;
		$img->write(file=>$filename) or
        		die $img->errstr;
		$snapshot_no++;
	}
	push @times, time();
}

{
	print "Writing final snapshot ($snapshot_no).\n";
	my $filename = $outfile_basename . 
			($new_file ?
				sprintf(
				"\%0${variable_filename_length}i",
				$snapshot_no)
				: ''
			) .
			$outfile_extension;
	$img->write(file=>$filename) or
       		die $img->errstr;
	$snapshot_no++;
}

{
	@times = map $_-$times[0], @times;
	$times[$_] = $times[$_] - $times[$_-1] for 1..$#times;
	shift @times;

	my $sum;
	$sum += $_ for @times;
	my $ave = $sum / @times;
	print "A simulation step took in average $ave seconds.\n";
	$ave = $sum / $iterations;
	print "A simulation iteration took in average $ave seconds.\n";
	printf "That's %.4f iterations per second.\n", ($ave==0?0:1/$ave);
	print "(The above estimation is off by the amount of time it took\n";
	print "to draw into the image and write the image snapshot.)\n";
	print "The simulation steps took this many seconds each:\n";
	while (@times % 3) {
		push @times, 0;
	}
	for(my $i = 0; $i < @times; $i += 3) {
		printf("$i: %.8f, %.8f, %.8f\n", @times[$i..$i+2]);
	}
}

