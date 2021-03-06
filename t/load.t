# -*- cperl -*-

use ExtUtils::testlib;
use Test::More tests => 115;
use Test::Exception ;
use Test::Differences ;
use Test::Memory::Cycle;
use Config::Model;
use Data::Dumper ;
use Log::Log4perl qw(:easy :levels) ;

use warnings;
no warnings qw(once);

use strict;

my $model = Config::Model -> new(legacy => 'ignore',)  ;

my $arg = shift || '';
my ($log,$show) = (0) x 2 ;

my $trace = $arg =~ /t/ ? 1 : 0 ;
$log                = 1 if $arg =~ /l/;
$show               = 1 if $arg =~ /s/;

my $home = $ENV{HOME} || "";
my $log4perl_user_conf_file = "$home/.log4config-model";

if ($log and -e $log4perl_user_conf_file ) {
    Log::Log4perl::init($log4perl_user_conf_file);
}
else {
    Log::Log4perl->easy_init($log ? $WARN: $ERROR);
}

Config::Model::Exception::Any->Trace(1) if $arg =~ /e/;

# See caveats in Test::More doc
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";


ok(1,"compiled");

# test mega regexp, 'x' means undef
my @regexp_test 
  = (
     [ 'a'               , ['a', 'x' ,  'x'    ,'x' , 'x'     , 'x'  ]],
     [ '#C'              , ['x', 'x' ,  'x'    ,'x' , 'x'     , 'C'  ]],
     [ '#"m C"'          , ['x', 'x' ,  'x'    ,'x' , 'x'     , 'm C']],
     [ 'a=b'             , ['a', 'x' ,  'x'    ,'=' , 'b'     , 'x'  ]],
     [ 'a-z=b'           , ['a-z','x' , 'x'    ,'=' , 'b'     , 'x'  ]],
     [ "a=\x{263A}"      , ['a', 'x' ,  'x'    ,'=' , "\x{263A}" , 'x'  ]], # utf8 smiley
     [ 'a.=b'            , ['a', 'x' ,  'x'    ,'.=','b'      , 'x'  ]],
     [ "a.=\x{263A}"     , ['a', 'x' ,  'x'    ,'.=', "\x{263A}" , 'x'  ]], # utf8 smiley
     [ 'a="b=c"'         , ['a', 'x' ,  'x'    ,'=' , 'b=c'   , 'x'  ]],
     [ 'a="b=\"c\""'     , ['a', 'x' ,  'x'    ,'=' , 'b="c"' , 'x'  ]],
     [ 'a:b=c'           , ['a', ':' ,  'b'    ,'=' , 'c'     , 'x'  ]],
     [ 'a:"b\""="\"c"'   , ['a', ':' ,  'b"'   ,'=' ,'"c'     , 'x'  ]],
     [ 'a=~/b.*/'        , ['a', '=~', '/b.*/' ,'x' , 'x'     , 'x'  ]],
     [ 'a=~/b.*/.="\"a"' , ['a', '=~', '/b.*/' ,'.=','"a'     , 'x'  ]],
     [ 'a=b,c,d'         , ['a', 'x' ,  'x'    ,'=' , 'b,c,d' , 'x'  ]],
     [ 'm=a,"a b "'      , ['m', 'x' ,  'x'    ,'=' , 'a,"a b "', 'x'  ]],
     [ 'a#B'             , ['a', 'x' ,  'x'    ,'x' , 'x'     , 'B'  ]],
     [ 'a#"b=c"'         , ['a', 'x' ,  'x'    ,'x' , 'x'     , 'b=c']],
     [ 'a:"b\""#"\"c"'   , ['a', ':' ,  'b"'   ,'x' , 'x'     ,'"c'  ]],
     [ 'a=b#B'           , ['a', 'x' ,  'x'    ,'=' , 'b'     , 'B'  ]],
     [ 'a:b=c#C'         , ['a', ':' ,  'b'    ,'=' , 'c'     , 'C'  ]],
     [ 'a:b#C'           , ['a', ':' ,  'b'    ,'x' , 'x'     , 'C'  ]],
     [ 'a~b'             , ['a', '~' ,  'b'    ,'x' , 'x'     , 'x'  ]],
     [ 'a~'              , ['a', '~' ,  'x'    ,'x' , 'x'     , 'x'  ]],
    ) ;

foreach my $subtest (@regexp_test) {
    my ($cmd, $ref) = @$subtest ;
    my $res = Config::Model::Loader::_split_cmd($cmd) ;
    #print Dumper $res,"\n";
    foreach (@$res) { $_ = 'x' unless defined $_ ;} 
    eq_or_diff($res,$ref, "test _split_cmd with '$cmd'") ;
}

my $inst = $model->instance (root_class_name => 'Master', 
                 model_file => 't/dump_load_model.pm',
                 instance_name => 'test1');
ok($inst,"created dummy instance") ;

my $root = $inst -> config_root ;

# check with embedded \n
my $step = qq!#"root cooment " std_id:ab X=Bv -\na_string="titi and\ntoto" !;
ok( $root->load( step => $step, experience => 'advanced' ),
  "load steps with embedded \\n");
is( $root->fetch_element('a_string')->fetch, "titi and\ntoto",
  "check a_string");

# check with embedded quotes
$step = qq!std_id:ab X=Bv -\na_string="\"titi\" and \"toto\"" std_id:bc X=Av!;
ok( $root->load( step => $step, experience => 'advanced' ),
  "load steps with embedded quotes");
is( $root->fetch_element('a_string')->fetch, qq!"titi" and "toto"!,
  "check a_string with embedded quotes");

# check with embedded utf8
$step = qq!#"root cooment \x{263A} " std_id:\x{263A} X=Bv -\na_string="titi and\ntoto and \x{263A}" !;
ok( $root->load( step => $step, experience => 'advanced' ),
  "load steps with embedded \x{263A}");
is( $root->fetch_element('a_string')->fetch, "titi and\ntoto and \x{263A}",
  "check a_string");
is( $root->fetch_element('std_id')->fetch_with_id("\x{263A}")->fetch_element_value('X'), 'Bv',
  "check hash with utf8 index");

$step = 'std_id:ab X=Bv - std_id:bc X=Av - a_string="titi , toto" ';
ok( $root->load( step => $step, experience => 'advanced' ),
  "load '$step'");
is( $root->fetch_element('a_string')->fetch, 'titi , toto',
  "check a_string");

# check that we can go to root node starting from below
my $stdab = $root->grab("std_id:ab") ;
$stdab->load("! a_string=titi");
ok(1,"go to root node starting from below");

ok( $root->load( step => 'tree_macro=XZ', experience => 'advanced' ),
  "Set tree_macro to XZ");

# test load with warped_node below root (used to fail)
$step = 'slave_y warp2 aa2="foo bar baz"';
ok( $root->load( step => $step, experience => 'advanced' ),
  "load '$step'");

# this will warp out slave_y warp2
ok( $root->load( step => 'tree_macro=XY', experience => 'advanced' ),
  "Set tree_macro to XY");

# use indexes with white spaces

$step = 'std_id:"a b" X=Bv - std_id:" b  c " X=Av " ';
ok( $root->load( step => $step, experience => 'advanced' ),
  "load '$step'");

is_deeply([ $root->fetch_element('std_id')->fetch_all_indexes ],
      [ ' b  c ', 'a b','ab','bc',"\x{263A}"],
      "check indexes");

$step = 'std_id:ab ZZX=Bv - std_id:bc X=Bv';
throws_ok {$root->load( step => $step, experience => 'advanced' );}
  "Config::Model::Exception::UnknownElement", "load wrong '$step'";

$step = 'lista=a,b,c,d olist:0 X=Av - olist:1 X=Bv - listb=b,c,d,,f,"",h,0';
throws_ok { $root->load( step => $step, experience => 'advanced');} 
  qr/comma/, "load wrong '$step'";

$step = 'listb=b,c,d,f,"",h,0';
ok ( $root->load( step => $step, experience => 'advanced'),
     "load '$step'");

# perform some checks
my $olist = $root->fetch_element('olist') ;
is($olist->fetch_with_id(0)->element_name, 'olist', 'check list element_name') ;

map {
    is($olist->fetch_with_id($_)->config_class_name, 'SlaveZ', 
       "check list element $_ class") ;
    } (0,1) ;

my $lista = $root->fetch_element('lista') ;
isa_ok($lista, 'Config::Model::ListId','check lista class');
map {
    isa_ok($lista->fetch_with_id($_), 'Config::Model::Value', 
       "check lista element $_ class") ;
    } (0,1) ;

is($olist->fetch_with_id(0)->fetch_element('X')->fetch, 'Av', 
   "check list element 0 content") ;
is($olist->fetch_with_id(1)->fetch_element('X')->fetch, 'Bv', 
   "check list element 1 content") ;

my @expect = qw/a b c d/;
map {
    is($lista->fetch_with_id($_)->fetch, $expect[$_], 
       "check lista element $_ content") ;
    } (0 .. $#expect) ;

my $listb = $root->fetch_element('listb') ;
@expect = (qw/b c d/,'f','','h','0');
map {
    is($listb->fetch_with_id($_)->fetch, $expect[$_], 
       "check listb element $_ content") ;
    } (0 .. $#expect) ;

$step = 'a_string="foo bar"';
ok( $root->load( step => $step, ), "load quoted string: '$step'");
is( $root->fetch_element('a_string')->fetch, "foo bar",
  'check result');


$step = 'a_string="foo bar baz" lista=a,b,c,d,e';
ok( $root->load( step => $step, ), "load : '$step'");
is( $root->fetch_element('a_string')->fetch, "foo bar baz",
  'check result' );

@expect = qw/a b c d e/;
map {
    is($lista->fetch_with_id($_)->fetch, $expect[$_], 
       "check lista element $_ content") ;
    } (0 .. 4) ;

# set the value of the previous object
$step = 'std_id:"f/o/o:b.ar" X=Bv' ;
ok( $root->load( step => $step, ), "load : '$step'");
is_deeply( [sort $root->fetch_element('std_id')->fetch_all_indexes ],
       [' b  c ', 'a b',qw!ab bc f/o/o:b.ar!,"\x{263A}"],
       "check result after load '$step'" );

$step = 'hash_a:a=z hash_a:b=z2 hash_a:"a b "="z 1"' ;
ok( $root->load( step => $step, ), "load : '$step'");
is_deeply( [sort $root->fetch_element('hash_a')->fetch_all_indexes ],
       ['a','a b ','b'],
       "check result after load '$step'" );
is($root->fetch_element('hash_a')->fetch_with_id('a')->fetch,'z',
   'check result');

my $elt = $root->fetch_element('hash_a')->fetch_with_id('a b ');
is($elt->fetch,'z 1', 'check result with white spaces');

is ($elt->location,'hash_a:"a b "', 'check location') ;

$step = 'my_check_list=a,"a b "' ;
ok( $root->load( step => $step, ), "load : '$step'");

$step = 'a_string="a \"b\" "' ;
ok( $root->load( step => $step, ), "load : '$step'");
is($root->fetch_element('a_string')->fetch , 'a "b" ',
  "test value loaded by '$step'");

$step = 'lista=a,"a \"b\" "' ;
ok( $root->load( step => $step, ), "load : '$step'");
is($root->fetch_element('lista')->fetch_with_id(1)->fetch ,
   'a "b" ',
   "test value loaded by '$step'");

$step = 'lista~1 hash_a~"a b "' ;
ok( $root->load( step => $step, ), "load : '$step'");
is($root->fetch_element('lista')->fetch_with_id(1)->fetch ,
   undef,
   "test list value loaded by '$step'");
$elt = $root->fetch_element('hash_a')->fetch_with_id('a b ');
is($elt->fetch,undef, "test hash value loaded by '$step'");

# test append mode
$root->load('a_string.=c');
is($root->fetch_element_value('a_string'), 'a "b" c', "test append on list");
# test append mode with utf8
$root->load("a_string.=\x{263A}");
is($root->fetch_element_value('a_string'), 'a "b" c'."\x{263A}", "test append on list with utf8");

$root->load('lista:0.=" b c"');
is($root->fetch_element('lista')->fetch_with_id(0)->fetch ,
   , 'a b c', "test append on leaf");

$root->load('hash_a:b.=" z3"');
is($root->fetch_element('hash_a')->fetch_with_id('b')->fetch ,
   , 'z2 z3', "test append on hash");

# test loop mode

$root->load('std_id=~/^\w+$/ DX=Bv - int_v=9') ;
is($root->grab_value('std_id:ab DX'),'Bv',"check looped assign 1") ;
is($root->grab_value('std_id:bc DX'),'Bv',"check looped assign 2") ;
isnt($root->grab_value('std_id:"a b" DX'),'Bv',"check out of loop left alone") ;

# test annotation setting
my @anno_test = ( 'std_id',
          'std_id:ab',
          'lista',
          'lista:0',
        );
foreach my $path (@anno_test) {
    $root->load(qq!$path#"$path annotation"!) ;
    is($root->grab($path)->annotation,"$path annotation",
       "fetch $path annotation") ;
}

# test combination of annotation plus load and some utf8
$step = 'std_id#std_id_note ! std_id:ab#std_id_ab_note X=Bv X#X_note 
      - std_id:bc X=Av X#X2_note '
  . '- a_string="toto \"titi\" tata" a_string#string_note '
  . 'lista=a,b,c,d olist:0 - olist:0#olist0_note X=Av - olist:1 X=Bv - listb=b,"c c2",d '
  . '! hash_a:X2=x#x_note hash_a:Y2=xy  hash_b:X3=xy my_check_list=X2,X3 '
  . 'plain_object#"plain comment" aa2="aa2_value '."\x{263A}\"" ;

my $inst2 = $model->instance (root_class_name => 'Master', 
                              instance_name => 'test2');

my $root2 = $inst2 -> config_root ;

ok( $root2->load( step => $step, experience => 'advanced' ),
  "set up data in tree with combination of load and annotations");

my @to_check = ( 
		 [ 'std_id','std_id_note' ],
		 [ 'std_id:ab','std_id_ab_note' ],
		 [ 'std_id:ab X','X_note' ],
		 [ 'std_id:bc X','X2_note' ],
		 [ 'a_string','string_note'],
		 [ 'olist:0','olist0_note'],
		 [ 'hash_a:X2','x_note'],
		 [ 'plain_object', 'plain comment' ],
	       ) ;
foreach (@to_check) {
    is($root2->grab($_->[0])->annotation,$_->[1],
       "Check annotation for '$_->[0]'") ;
}

# check utf8 value
is($root2->grab_value('plain_object aa2'), "aa2_value \x{263A}","utf8 value") ;


# test deletion of leaf items
$step = 'a_string=foobar a_string~';
ok( $root2->load( step => $step, experience => 'advanced' ),
  "set up data then delete it");
  
is($root2->grab_value('a_string'),undef,"check that another_string was undef'ed");

$root2->load("lista:0.=\x{263A}") ;
is($root2->grab_value('lista:0'),"a\x{263A}","check that list append work");

# test element with embedded dash
$root->load("std_id:ab X-Y-Z=Av");
is($root->grab_value('std_id:ab X-Y-Z'), "Av","check load grab of X-Y-Z") ;

# test some errors cases
my %errors = ( 
    'std_id', qr/Missing assignment/ ,
    'olist', qr/Wrong assignment/,
);

foreach my $bad (sort keys %errors) {
    throws_ok { $root->load($bad) }  $errors{$bad}, "Check error for load('$bad')" ;
}

memory_cycle_ok($model);
