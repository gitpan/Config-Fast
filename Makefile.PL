use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Config::Fast',
    'VERSION_FROM' => 'Fast.pm', # finds $VERSION
);
