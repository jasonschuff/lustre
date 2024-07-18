#### Fileclasses definitions ####

FileClass small_files {
    definition { type == file and size > 0 and size <= 16MB }
    # report = yes (default)
}
FileClass std_files {
    definition { type == file and size > 16MB and size <= 1GB }
}
FileClass big_files {
    definition { type == file and size > 1GB }
}

lhsm_config {
    # used for 'undelete': command to change the fid of an entry in archive
    rebind_cmd = "/usr/sbin/lhsmtool_posix --hsm_root=/tmp/backend --archive {archive_id} --rebind {oldfid} {newfid} {fsroot}";
}

lhsm_archive_parameters {
    nb_threads = 1;

    # limit archive rate to avoid flooding the MDT coordinator
    schedulers = common.rate_limit;
    rate_limit {
        # max count per period
        max_count = 1000;
        # max size per period: 1GB/s
        #max_size = 10GB;
        # period, in milliseconds: 10s
        period_ms = 10000;
    }

    # suspend policy run if action error rate > 50% (after 100 errors)
    suspend_error_pct = 50%;
    suspend_error_min= 100;

    # overrides policy default action
    action = cmd("lfs hsm_archive --archive {archive_id} /lustre/.lustre/fid/{fid}");

    # default action parameters
    action_params {
        archive_id = 1;
    }
}

lhsm_archive_rules {
    rule archive_small {
        target_fileclass = small_files;
        condition { last_mod >= 1min }
    }

    rule archive_std {
        target_fileclass = std_files;
        target_fileclass = big_files;
        condition { last_mod >= 1min }
    }

    # fallback rule
    rule default {
        condition { last_mod >= 1min }
    }
}

# run every 5 min
lhsm_archive_trigger {
    trigger_on = periodic;
    check_interval = 1min;
}

#### Lustre/HSM release configuration ####

lhsm_release_rules {
    # keep small files on disk as long as possible
    rule release_small {
        target_fileclass = small_files;
        condition { last_access > 1y }
    }

    rule release_std {
        target_fileclass = std_files;
        target_fileclass = big_files;
        condition { last_access > 1d }
    }

    # fallback rule
    rule default {
        condition { last_access > 6h }
    }
}

# run 'lhsm_release' on full OSTs
lhsm_release_trigger {
    trigger_on = ost_usage;
    high_threshold_pct = 85%;
    low_threshold_pct  = 80%;
    check_interval     = 5min;
}

lhsm_release_parameters {
    nb_threads = 4;
## purge 1000 files max at once
#    max_action_count = 1000;
#    max_action_volume = 1TB;

    # suspend policy run if action error rate > 50% (after 100 errors)
    suspend_error_pct = 50%;
    suspend_error_min= 100;
}

lhsm_remove_parameters
{
    # overrides policy default action
    action = cmd("/usr/sbin/lfs_hsm_remove.sh {fsroot} {fullpath} {archive_id} {fid}");

    # default action parameters
    action_params {
        archive_id = 1;
    } 
}

#### Lustre/HSM remove configuration ####
lhsm_remove_rules
{
    # cleanup backend files after 1m
    rule default {
        condition { rm_time >= 1m }
    }
}

# run daily
lhsm_remove_trigger
{
    trigger_on = periodic;
    check_interval = 1m;
}