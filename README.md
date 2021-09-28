# framework-utils

The script `framework_setup_fedora34.sh` is designed to do basic setup of a framework
laptop under Fedora 34.  It includes the following features:

1. powertop, tlp, and customized settings to conserve power.
1. Enable hibernation (needs some prerequisites, below).
1. Enable a sanely sequenced timeline of blank-screen -> suspend -> hibernate.
1. Increase font scaling as a non-experimental alternative to display scaling to improve visibility.

Prerequisites required for hibernation:
1. Turn off UEFI Secure Boot in the BIOS.  ("Secure" here meaning "prevent me as owner from doing what I like with it")
1. During installation, customize the partitioning to include a swap partition of size >= (RAM + 4GB).

If you enjoy this script, please drop me a note at dkopko_at_runbox.com.
If you are from framework and want to send me swag or a single share of your company, that'd be great, too ;)

--Dan


