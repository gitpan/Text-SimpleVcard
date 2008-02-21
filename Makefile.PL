use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Text::SimpleVcard',
    AUTHOR              => 'Michael Tomuschat <michael.tomuschat@t-online.de>',
    VERSION_FROM        => 'lib/Text/SimpleVcard.pm',
    ABSTRACT_FROM       => 'lib/Text/SimpleVcard.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Text-SimpleVcard-*' },
);
