#!/usr/bin/perl

use LWP::UserAgent;
use HTML::Form;
use Term::ReadKey;
use Config;
my $have_tk = eval "require Tk::LabEntry;\n require Tk::DialogBox;";

local $| = 1;  # autoflush stdout
my $filename;

sub get_info_graphical{
  my $mw = MainWindow->new();
  $mw->withdraw();

  my $db = $mw->DialogBox(-title => 'Enter username/password for gorubi.com', -buttons => ['Ok', 'Cancel'], 
                       -default_button => 'Ok');
  $db->Label(-text => "Enter gorubi credentials")->pack( );
  $db->add('LabEntry', -textvariable => \$email, -width => 30, 
           -label => 'Email', -labelPack => [-side => 'left'])->pack;
  $db->add('LabEntry', -textvariable => \$password, -width => 26, 
            -label => 'Password', -show => '*', 
            -labelPack => [-side => 'left'])->pack;
  $answer = $db->Show( );

  if ($answer ne "Ok") {
    exit (1);
  }
  return ($email, $password)
}

sub get_info_cli{
  print "Enter your user email for gurobi.com: ";
  chomp(my $email = <>);
  print "Enter your password for gurobi.com: ";
  ReadMode('noecho');
  chomp(my $password = <>);
  ReadMode('restore');
  return ($email, $password)
}

sub get_email_and_password{
  if ($have_tk){
    return get_info_graphical();
  }
  else{
    return get_info_cli();
  }
}


if ( $ENV{'GUROBI_DISTRO'} ) {
  $filename = $ENV{'GUROBI_DISTRO'};
  print "Using GUROBI_DISTRO file $ENV{'GUROBI_DISTRO'}\n";
} else {
  my @forms;
  my $response;
  my $mech = LWP::UserAgent->new;
  $mech->cookie_jar( {} );

  while(1) {
    my ($email, $password) = get_email_and_password();

    $response = $mech->get( "http://www.gurobi.com/login" );
    @forms = HTML::Form->parse( $response );

    $form = shift(@forms);  # search form
    $form = shift(@forms);  # login form

    $form->value('email',$email);
    $form->value('password',$password);

    $response = $mech->request( $form->click );

    $response = $mech->get( "http://user.gurobi.com/download/gurobi-optimizer" );

    @forms = HTML::Form->parse( $response, "http://user.gurobi.com" );

    my $numforms = scalar @forms;
    if ( $numforms > 2 ) { # login failed page has two forms
      last;
    }

    print "Login failed.  Please try again.\n";
  }

  $form = shift(@forms);  # search form
  $form = shift(@forms);  # login form
  $form = shift(@forms);  # download form

  if ($^O eq 'darwin') {
      $filename = 'gurobi6.0.5a_mac64.pkg';
      $postfix = '/Mac OS';
  } elsif ($^O eq 'linux') {
      $filename = 'gurobi6.0.5_linux64.tar.gz';
      $postfix = '/Linux 64';
  }

  $form->value('filename','6.0.5/'.$filename);#.$postfix);

  print "\nDownloading $filename ... ";
  $response = $mech->request( $form->click , $filename);
  print "done\n";
  print $response->content();

  chomp($cwd = `pwd`);
  $filename = "$cwd/$filename"
}

if ($^O eq 'darwin') {
  system("mkdir","tmp");
  chdir("tmp");
  system("xar","-xf","$filename");
  chdir("gurobi605mac64tar.pkg");
  system("tar","-xvf","Payload");
  system("tar","-xvf","gurobi6.0.5_mac64.tar.gz");
  system("mv","gurobi605","../../");
  chdir("../..");
  system("rm","-rf","tmp");
#  system("rm","-rf",$filename);
} elsif ($^O eq 'linux') {
  system("tar","-xvf",$filename);
#  system("rm","-rf",$filename);
}
