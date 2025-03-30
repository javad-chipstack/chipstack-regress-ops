use strict;
use warnings;
use Getopt::Long;
use IPC::Open3;
use Symbol 'gensym';
use Cwd 'cwd';
use Time::HiRes qw(time);
use File::Path  qw(make_path rmtree);
use Proc::Background;
use Proc::Background;
use File::Path qw(rmtree make_path);
use Symbol 'gensym';

$| = 1;               # Flush output immediately
my $verbosity = 0;    # Set to 1 for verbose output, 0 for silent

our $CONFIG = {
    chipstack_ai_repo      => "/home/javad/dev/chipstack-ai",
    python_bin_path        => "/home/javad/.pyenv/shims/python",
    outdir                 => cwd() . "/outdir",
    target_branches        => "main",
    server_restart_docker  => 1,
    design_set             => "dev_v3_mini",
    server_url             => "http://localhost:8000/",
    eda_url                => "https://eda.chipstack.ai/",
    llm_flow               => "default",
    syntax_check_provider  => "verific",
    enable_project_support => "true",
    use_primitives         => "false",
    iterate_sim            => "false",
    random_restarts        => 0,
    run_type               => "Simulation"
};

GetOptions(
    "target_branches=s"        => \$CONFIG->{target_branches},
    "outdir=s"                 => \$CONFIG->{outdir},
    "server_restart_docker=s"  => \$CONFIG->{server_restart_docker},
    "design_set=s"             => \$CONFIG->{design_set},
    "server_url=s"             => \$CONFIG->{server_url},
    "eda_url=s"                => \$CONFIG->{eda_url},
    "llm_flow=s"               => \$CONFIG->{llm_flow},
    "syntax_check_provider=s"  => \$CONFIG->{syntax_check_provider},
    "enable_project_support=s" => \$CONFIG->{enable_project_support},
    "use_primitives=s"         => \$CONFIG->{use_primitives},
    "iterate_sim=s"            => \$CONFIG->{iterate_sim},
    "random_restarts=i"        => \$CONFIG->{random_restarts},
    "run_type=s"               => \$CONFIG->{run_type}
) or die "[ERROR] Invalid command-line arguments\n";

sub create_log_dir_name {
    my ( $cmd, $index, $outdir ) = @_;
    $cmd =~ s/[^a-zA-Z0-9_\-]/_/g;
    $cmd   = substr( $cmd, 0, 40 ) if length($cmd) > 40;
    $index = sprintf( "%03d", $index );
    return "$outdir/logs/${index}_$cmd";
}

sub run_command {
    my ( $cmd, $index, $outdir, $verbosity ) = @_;

    # Create log directory
    my $cmd_log_dir = create_log_dir_name( $cmd, $index, $outdir );
    if ( -d $cmd_log_dir ) {
        print "[INFO] Removing existing directory: $cmd_log_dir\n"
          if $verbosity;
        rmtree($cmd_log_dir) or die "Cannot remove directory $cmd_log_dir: $!";
    }
    print "[INFO] Creating directory: $cmd_log_dir\n" if $verbosity;
    make_path($cmd_log_dir) or die "Cannot create directory $cmd_log_dir: $!";

    # Define file paths for capturing stdout, stderr, and exit code
    my ( $stdout_file, $stderr_file, $exit_code_file ) = (
        "$cmd_log_dir/stdout.log", "$cmd_log_dir/stderr.log",
        "$cmd_log_dir/exit_code.log"
    );

    # Open files for logging stdout and stderr
    open my $fh_out, '>', $stdout_file or die "Cannot open $stdout_file: $!";
    open my $fh_err, '>', $stderr_file or die "Cannot open $stderr_file: $!";

    print "[CMD] $cmd\n";

# Launch the command using Proc::Background, with output redirected to filehandles
    my $proc =
      Proc::Background->new( { stdout => $fh_out, stderr => $fh_err }, $cmd );

    # Close filehandles to ensure the buffering is managed properly
    close $fh_out;
    close $fh_err;

    # Wait for the process to finish and capture its exit code
    $proc->wait();
    my $exit_code = $proc->wait();

    # Save the exit code to a file
    open my $fh_exit, '>', $exit_code_file
      or die "Cannot open $exit_code_file: $!";
    print $fh_exit $exit_code;
    close $fh_exit;

    # If the command failed, display an error
    if ( $exit_code != 0 ) {
        die "[ERROR] Command failed: $cmd\nCheck logs at $cmd_log_dir";
    }

    return $exit_code;
}

sub setup_working_directory {
    chdir( $CONFIG->{chipstack_ai_repo} )
      or die
      "[ERROR] Cannot change directory to $CONFIG->{chipstack_ai_repo}: $!";
}

sub restartdocker {
    if ( !defined $CONFIG->{server_restart_docker} ) {
        die "[ERROR] server_restart_docker is not defined.\n";
    }
    elsif ( $CONFIG->{server_restart_docker} !~ /^hard$|^soft$|^none$/ ) {
        die "[ERROR] server_restart_docker must be hard, soft or none."
          . " $CONFIG->{server_restart_docker} is not acceptable.\n";
    }
    elsif ( $CONFIG->{server_restart_docker} eq "none" ) {
        print "[INFO] Skipping Docker restart.\n";
        return;
    }
    my ( $hardrestart, $outdir ) = @_;
    my $server_dir = $CONFIG->{chipstack_ai_repo} . "/server";
    chdir($server_dir)
      or die "[ERROR] Cannot change directory to $server_dir: $!";

    if ( $CONFIG->{server_restart_docker} eq "hard" ) {
        run_command( "make hardrestartdocker", 12, $outdir );
    }
    elsif ( $CONFIG->{server_restart_docker} eq "soft" ) {
        run_command( "make restartdocker", 12, $outdir );
    }

    print "[INFO] Waiting for Docker logs to show "
      . "'Application startup complete.'\n";

    my $start_time = time();
    my $timeout    = 20 * 60;    # 20 minutes in seconds
    my $log_command =
      "docker logs -f server-server-1 2>&1";    # Redirect stderr to stdout

    open my $log_fh, '-|', $log_command
      or die "[ERROR] Cannot execute: $log_command\n";
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm $timeout;
        while ( my $line = <$log_fh> ) {
            $line =~ s/^/    /mg;    # Add indentation to all lines
            print $line;
            if ( $line =~ /Application startup complete\./ ) {
                print "[INFO] Application startup detected.\n";
                last;
            }
        }
        alarm 0;
    };
    if ($@) {
        die "[ERROR] Timeout reached while waiting for application startup.\n"
          if $@ eq "timeout\n";
        die $@;
    }
    close $log_fh;
}

sub get_var_name_for_branch {
    my ($branch) = @_;
    my $human_readable_name = $branch;
    $human_readable_name =~ s/[^a-zA-Z0-9_-]/_/g;
    $human_readable_name .=
      "_" . join( "", map { ( "a" .. "z", 0 .. 9 )[ rand 36 ] } 1 .. 10 );
    return $human_readable_name;
}

sub main {
    setup_working_directory();
    if ( -d $CONFIG->{outdir} ) {
        print "[INFO] Removing existing content in $CONFIG->{outdir}\n"
          if $verbosity;
        rmtree( $CONFIG->{outdir} )
          or die "Cannot remove directory $CONFIG->{outdir}: $!";
    }

    for my $curr_branch ( split( /[,\n\r\s]+/, $CONFIG->{target_branches} ) ) {
        my $curr_branch_var_name = get_var_name_for_branch($curr_branch);
        my $cur_outdir           = $CONFIG->{outdir} . "/$curr_branch_var_name";

        my @commands = (
            "gcloud auth activate-service-account "
              . "--key-file=/home/javad/dev/chipstack-regress-ops/keys/service-account-key-kpi.json",
            "gcloud auth print-access-token"
              . " | docker login -u oauth2accesstoken "
              . "--password-stdin https://us-west1-docker.pkg.dev",
            "git stash push -m 'Auto-stash before reset'",
            "git checkout main",
            "git pull",
            "git reset --hard origin/main",
            "git clean -fd",
            "git pull",
            "git checkout $curr_branch",
            "git pull",
            "git branch --show-current",
            "git log -1 --oneline"
        );
        if ( !-d $cur_outdir ) {
            make_path($cur_outdir)
              or die "Cannot create log directory: $cur_outdir\n";
        }
        foreach my $index ( 0 .. $#commands ) {
            my $cmd = $commands[$index];
            run_command( $cmd, $index, $cur_outdir );
        }
        restartdocker( $CONFIG->{server_restart_docker}, $cur_outdir );

        my $python_path = join(
            ":",
            (
                "$CONFIG->{chipstack_ai_repo}/common",
                "$CONFIG->{chipstack_ai_repo}/client",
                "$CONFIG->{chipstack_ai_repo}/kpi"
            )
        );

        my $kpi_path      = "$CONFIG->{chipstack_ai_repo}/kpi/chipstack_kpi";
        my $final_command = join(
            " ",
            (
                "export PYTHONPATH=$python_path:\$PYTHONPATH ;",
                $CONFIG->{python_bin_path},
                "$kpi_path/app/unit_test_kpi_run.py",
                "--design_file $kpi_path/configs/$CONFIG->{design_set}.yaml",
                "--server_url $CONFIG->{server_url}",
                "--eda_url $CONFIG->{eda_url}",
                "--llm_flow $CONFIG->{llm_flow}",
                "--syntax_check_provider $CONFIG->{syntax_check_provider}",
                "--output_dir $cur_outdir/outdir_kpi",
                "--enable_project_support $CONFIG->{enable_project_support}",
                "--use_primitives $CONFIG->{use_primitives}",
                "--iterate_simulation_results $CONFIG->{iterate_sim}",
                "--num_random_restarts $CONFIG->{random_restarts}",
                "--run_type $CONFIG->{run_type}"
            )
        );
        run_command( $final_command, 13, $cur_outdir );
    }

    print "[INFO] Script execution completed successfully.\n";
}
main();
