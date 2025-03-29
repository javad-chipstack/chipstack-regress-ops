use strict;
use warnings;
use Getopt::Long;
use IPC::Open3;
use Symbol 'gensym';
use Cwd 'cwd';
use Time::HiRes qw(time);

our $CONFIG = {
    chipstack_ai_repo      => "/home/javad/dev/chipstack-ai",
    python_bin_path        => "/home/javad/.pyenv/shims/python",
    outdir                 => cwd() . "/outdir",
    target_branch          => "main",
    hardrestartdocker      => 0,
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
    "target_branch=s"          => \$CONFIG->{target_branch},
    "outdir=s"                 => \$CONFIG->{outdir},
    "hardrestartdocker!"       => \$CONFIG->{hardrestartdocker},
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

sub run_command {
    my ( $cmd, $cmd_log_dir ) = @_;
    mkdir $cmd_log_dir or die "Cannot create directory $cmd_log_dir: $!";
    my ( $stdout_file, $stderr_file, $exit_code_file ) = (
        "$cmd_log_dir/stdout.log", "$cmd_log_dir/stderr.log",
        "$cmd_log_dir/exit_code.log"
    );
    print "[CMD] $cmd\n";
    my $exit_code = system("$cmd >$stdout_file 2>$stderr_file");
    open my $fh_exit, '>', $exit_code_file
      or die "Cannot open $exit_code_file: $!";
    print $fh_exit $exit_code;
    close $fh_exit;
    die "[ERROR] Command failed: $cmd\n" if $exit_code != 0;
    return $exit_code;
}

sub setup_working_directory {
    chdir( $CONFIG->{chipstack_ai_repo} )
      or die
      "[ERROR] Cannot change directory to $CONFIG->{chipstack_ai_repo}: $!";
}

sub run_make_hardrestartdocker {
    my $server_dir = $CONFIG->{chipstack_ai_repo} . "/server";
    chdir($server_dir)
      or die "[ERROR] Cannot change directory to $server_dir: $!";
    run_command( "make hardrestartdocker",
        "$CONFIG->{outdir}/logs_make_hardrestartdocker" );
}

sub main {
    setup_working_directory();
    my @commands = (
        "git stash push -m 'Auto-stash before reset'",
        "git checkout main",
        "git pull",
        "git reset --hard origin/main",
        "git clean -fd",
        "git pull",
        "git checkout $CONFIG->{target_branch}",
        "git pull",
        "git branch --show-current",
        "git log -1 --oneline"
    );
    my $log_dir = "$CONFIG->{outdir}/logs_" . time;
    mkdir $log_dir or die "Cannot create log directory: $log_dir\n";
    foreach my $cmd (@commands) {
        run_command( $cmd, "$log_dir/" . time );
    }
    run_make_hardrestartdocker() if $CONFIG->{hardrestartdocker};
    my $python_path = join( ":",
        "$CONFIG->{chipstack_ai_repo}/common",
        "$CONFIG->{chipstack_ai_repo}/client",
        "$CONFIG->{chipstack_ai_repo}/kpi" );

    my $kpi_path      = "$CONFIG->{chipstack_ai_repo}/kpi/chipstack_kpi";
    my $final_command = join( " ",
        "export PYTHONPATH=$python_path:\$PYTHONPATH ;",
        $CONFIG->{python_bin_path},
        "$kpi_path/app/unit_test_kpi_run.py",
        "--design_file $kpi_path/configs/$CONFIG->{design_set}.yaml",
        "--server_url $CONFIG->{server_url}",
        "--eda_url $CONFIG->{eda_url}",
        "--llm_flow $CONFIG->{llm_flow}",
        "--syntax_check_provider $CONFIG->{syntax_check_provider}",
        "--output_dir $CONFIG->{outdir}/outdir_kpi",
        "--enable_project_support $CONFIG->{enable_project_support}",
        "--use_primitives $CONFIG->{use_primitives}",
        "--iterate_simulation_results $CONFIG->{iterate_sim}",
        "--num_random_restarts $CONFIG->{random_restarts}",
        "--run_type $CONFIG->{run_type}" );
    print "[INFO] Running final command: $final_command\n";
    system($final_command) == 0
      or die "[ERROR] Final command execution failed!\n";
    print "[INFO] Script execution completed successfully.\n";
}

main();
