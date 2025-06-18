# UsefulSQL - SQL Server Scripts for the Real World

## What's This All About?

This is my collection of SQL Server scripts that I've built up over the years - the ones that actually get used when stuff hits the fan. If you're a junior sys admin, database admin, or just someone who has to deal with SQL Server whether you want to or not, these scripts will save you time and headaches.

I've written these to be practical, not pretty. They work, they're documented for people who don't live and breathe databases 24/7, and they'll give you the information you need to make decisions or answer questions from management.

**Fair warning**: Test these in a dev environment first. Don't be that person who runs random scripts in production.

## The Scripts That Matter

### 🔍 **Audit Scripts** (The Big Four)
These are your go-to scripts for understanding what you're dealing with when you inherit a SQL Server environment or need to document what you have.

#### SystemAudit.sql
**What it does**: Gives you the complete picture of your SQL Server environment - hardware, memory, storage, network configuration, and all the basic stuff you need to know.

**When to use it**: 
- New job, new SQL Server to figure out
- Quarterly documentation updates
- Before making major changes
- When performance is acting weird and you need baseline info

**What you'll get**: Instance details, hardware specs, database file locations, memory configuration, service information. Think of it as your "SQL Server at a glance" report.

**Pro tip**: Run this first before any other troubleshooting. Half the time the problem is obvious once you see the configuration.

#### DatabaseInformation.sql
**What it does**: Inventories all your databases - sizes, recovery models, growth settings, and identifies which ones are actually important vs the test databases someone forgot to clean up.

**When to use it**:
- Planning storage upgrades
- Setting up backup strategies
- Cleaning up old/unused databases
- Capacity planning meetings

**What you'll get**: Database counts, size breakdowns, recovery model distribution, and a nice summary that makes sense to non-DBAs.

**Reality check**: You'll probably find databases you didn't know existed. Document them before deleting anything.

#### BackupSolution.sql
**What it does**: Analyzes your backup strategy (or lack thereof) and tells you what's actually being backed up, how often, and where those backups are going.

**When to use it**:
- Disaster recovery planning
- Compliance audits
- After inheriting a system
- When users ask "can we restore from last Tuesday?"

**What you'll get**: Backup frequencies, locations, retention analysis, and recommendations for improvement.

**Wake-up call**: This script will show you if you're one crash away from a resume-generating event.

#### ConfigurationMaintenance.sql
**What it does**: Examines SQL Server configuration settings, TempDB setup, monitoring tools, and maintenance plans to see if things are set up properly.

**When to use it**:
- Performance troubleshooting
- After SQL Server installation
- Quarterly health checks
- When things are "running slow"

**What you'll get**: Memory configuration analysis, TempDB configuration (super important), maintenance plan status, and operational health summary.

**Key insight**: Poor TempDB configuration is behind a lot of performance problems. This will tell you if that's your issue.

### 🔧 **Performance & Troubleshooting Scripts**

#### GetWaitStats.sql
**What it does**: Shows you what SQL Server is waiting for - the bottlenecks that are slowing things down.
**When to use it**: When performance is bad and you need to know why.

#### IndexFragmentation.sql / ReOrgIndexes.sql
**What they do**: Check how fragmented your indexes are and reorganize them.
**When to use them**: Monthly maintenance or when queries are getting slower.

#### QueryTuning.sql / IndexSuggestions.sql
**What they do**: Find expensive queries and suggest indexes to make them faster.
**When to use them**: Performance tuning or when users complain about slow reports.

#### DiskPerfStats.sql / SQL_FileSizes.sql
**What they do**: Check disk performance and file size growth patterns.
**When to use them**: Storage planning or investigating disk bottlenecks.

### 🛠 **Utility Scripts**

#### ValidationTest.sql
**What it does**: Tests if the audit scripts will work in your environment before you run them.
**When to use it**: Always run this first in new environments.

#### ChangeAllToSimple.sql
**What it does**: Changes all user databases to Simple recovery model.
**When to use it**: Development environments where you don't need point-in-time recovery.

#### CreateFillData.sql / RandomTestData.sql
**What they do**: Generate test data for development and testing.
**When to use them**: Setting up test environments.

## How to Use These Scripts

### For New Environments
1. Run `ValidationTest.sql` first
2. Run the four audit scripts: `SystemAudit.sql`, `DatabaseInformation.sql`, `BackupSolution.sql`, `ConfigurationMaintenance.sql`
3. Save the results - you'll thank me later

### For Regular Maintenance
- Run performance scripts monthly
- Run audit scripts quarterly
- Keep the results for trend analysis

### For Troubleshooting
- Start with `GetWaitStats.sql` to find bottlenecks
- Use specific scripts based on what you find

## What You Need to Know

**Permissions**: Most scripts need `VIEW SERVER STATE` and `VIEW ANY DATABASE` permissions. The backup script needs access to the `msdb` database. If you get permission errors, talk to your DBA or security team.

**SQL Server Versions**: These work on SQL Server 2008 R2 and later. Some features require newer versions - the scripts will tell you.

**Safety First**: These are read-only scripts (mostly), but test them in development first. Don't be the person who takes down production.

## The Fine Print

If you're making money with these scripts, throw some back my way. If they save your job, buy me a coffee. If they help you understand SQL Server better, that's payment enough.

These scripts work in my environments. They should work in yours, but I'm not responsible if your server explodes. Test first, deploy second.

## License
MIT License - Use them, modify them, share them. Just don't blame me if something goes wrong.