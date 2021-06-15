#
# This Makefile handles downloading data from Garmin Connect and generating SQLite DB files from that data. The Makefile targets handle the dependaancies
# between downloading and geenrating varies types of data. It wraps the core Python scripts and runs them with appropriate parameters.
#
export PROJECT_BASE=$(CURDIR)

include defines.mk


#
# Master targets
#
all: update_dbs

# install all needed code
setup: $(PROJECT_BASE)/.venv submodules_update deps install_all

clean_dbs: clean_mshealth_db clean_fitbit_db clean_garmin_dbs

# Use for an intial download or when the start dates have been changed.
download_all: download_all_garmin

# build dbs from already downloaded data files
build_dbs: build_garmin mshealth fitbit
create_dbs: garmin mshealth fitbit
create_copy_dbs: copy_garmin mshealth fitbit

# delete the exisitng dbs and build new dbs from already downloaded data files
rebuild_dbs: clean_dbs build_dbs
rebuild_mon_db: clean_garmin_monitoring_dbs build_garmin_monitoring
rebuild_act_db: clean_garmin_activities_dbs build_garmin_activities

# update the exisitng dbs by downloading data files for dates after the last in the dbs and update the dbs
update_dbs: update_garmin
update_dbs_bin: update_garmin_bin
update_copy_dbs: copy_garmin_latest

release: flake8 zip_packages


#
# Project maintainance targets
#
SUBMODULES=Fit Tcx utilities
SUBDIRS=FitBitDB GarminDB HealthDB MSHealthDB

$(PROJECT_BASE)/.venv:
	python3 -m venv $(PROJECT_BASE)/.venv

update: submodules_update
	git pull --rebase

submodules_update:
	git submodule init
	git submodule update

$(SUBMODULES:%=%-install):
	$(MAKE) -C $(subst -install,,$@) install

install: $(SUBMODULES:%=%-install)
	$(PYTHON) setup.py install

install_all: $(SUBMODULES:%=%-install) install

$(SUBMODULES:%=%-uninstall):
	$(MAKE) -C $(subst -uninstall,,$@) uninstall

uninstall:
	$(PIP) uninstall -y garmindb

uninstall_all: uninstall $(SUBMODULES:%=%-install)

$(SUBMODULES:%=%-deps):
	$(MAKE) -C $(subst -deps,,$@) deps

deps: $(SUBMODULES:%=%-deps)
	$(PIP) install --upgrade --requirement requirements.txt
	$(PIP) install --upgrade --requirement dev-requirements.txt

$(SUBMODULES:%=%-remove_deps):
	$(MAKE) -C $(subst -remove_deps,,$@) remove_deps

remove_deps: $(SUBMODULES:%=%-remove_deps)
	$(PIP) uninstall -y --requirement requirements.txt
	$(PIP) uninstall -y --requirement dev-requirements.txt

clean_deps: remove_deps

$(SUBMODULES:%=%-clean):
	$(MAKE) -C $(subst -clean,,$@) clean

$(SUBDIRS:%=%-clean):
	rm -f $(subst -clean,,$@)/*.pyc
	rm -rf $(subst -clean,,$@)/__pycache__

clean: $(SUBMODULES:%=%-clean) $(SUBDIRS:%=%-clean) test_clean
	rm -f *.pyc
	rm -f *.log
	rm -rf $(DIST)
	rm -rf build
	rm -f *.spec
	rm -f *.zip
	rm -f *.png
	rm -f ms_stats.txt
	rm -f stats.txt
	rm -rf __pycache__
	rm -rf GarminDb.egg-info
	rm -rf build
	rm -rf dist


#
# Fitness System independant targets
#
HEALTH_DATA_DIR=$(shell $(PYTHON) -c 'from garmindb import ConfigManager; print(ConfigManager.get_base_dir())')
DB_DIR=$(HEALTH_DATA_DIR)/DBs
BACKUP_DIR=$(HEALTH_DATA_DIR)/Backups
$(BACKUP_DIR):
	mkdir -p $(BACKUP_DIR)

EPOCH=$(shell date +'%s')
backup: $(BACKUP_DIR)
	zip -r $(BACKUP_DIR)/$(EPOCH)_dbs.zip $(DB_DIR)

VERSION=$(shell $(PYTHON) -c 'from version_info import version_string; print(version_string())')
BIN_FILES=$(DIST)/garmin $(DIST)/graphs $(DIST)/checkup $(DIST)/fitbit $(DIST)/mshealth
ZIP_FILES=dist_files/Readme_MacOS.txt dist_files/download_create_dbs.sh dist_files/download_update_dbs.sh dist_files/copy_create_dbs.sh \
	dist_files/copy_update_dbs.sh bugreport.sh
zip_packages: validate_garmin_package validate_fitbit_package validate_mshealth_package
	zip -j -r GarminDb_$(PLATFORM)_$(VERSION).zip GarminConnectConfig.json.example $(BIN_FILES) $(ZIP_FILES)

graphs:
	garmin_graphs.py --all

graph_yesterday:
	garmin_graphs.py --day $(YESTERDAY)

checkup: update_garmin
	garmin_checkup.py --battery
	garmin_checkup.py --goals

# define CHECKUP_COURSE_ID in my-defines.mk
checkup_course:
	garmin_heckup.py --course $(CHECKUP_COURSE_ID)

daily: all checkup graph_yesterday

#
# Garmin targets
#
download_all_garmin:
	garmin.py --all --download

redownload_garmin_activities:
	garmin.py --activities --download --overwrite

garmin:
	garmin.py --all --download --import --analyze

build_garmin:
	garmin.py --all --import --analyze

build_garmin_monitoring:
	garmin.py --monitoring --import --analyze

build_garmin_activities:
	garmin.py --activities --import --analyze

copy_garmin_settings:
	garmin.py --copy

copy_garmin:
	garmin.py --all --copy --import --analyze

update_garmin:
	garmin.py --all --download --import --analyze --latest

copy_garmin_latest:
	garmin.py --all --copy --import --analyze --latest

# define EXPORT_ACTIVITY_ID in my-defines.mk
export_activity:
	garmin.py --export-activity $(EXPORT_ACTIVITY_ID)

# define EXPORT_ACTIVITY_ID in my-defines.mk
basecamp_activity:
	garmin.py --basecamp-activity $(EXPORT_ACTIVITY_ID)

# define EXPORT_ACTIVITY_ID in my-defines.mk
google_earth_activity:
	garmin.py --google-earth-activity $(EXPORT_ACTIVITY_ID)

clean_garmin_dbs:
	garmin.py --delete_db --all

clean_garmin_monitoring_dbs:
	garmin.py --delete_db --monitoring

clean_garmin_activities_dbs:
	garmin.py --delete_db --activities


#
# FitBit target
#
fitbit:
	fitbit.py

clean_fitbit_db:
	fitbit.py --delete_db

validate_fitbit_package: $(DIST)/fitbit
	$(DIST)/fitbit -v


#
# MS Health target
#
mshealth: $(MSHEALTH_DB)
	mshealth.py

clean_mshealth_db:
	mshealth.py --delete_db

validate_mshealth_package: $(DIST)/mshealth
	$(DIST)/mshealth -v


#
# test targets
#
$(SUBMODULES:%=%-test):
	$(MAKE) -C $(subst -test,,$@) test

test: $(SUBMODULES:%=%-test)
	$(MAKE) -C test all

$(SUBMODULES:%=%-verify_commit):
	$(MAKE) -C $(subst -verify_commit,,$@) verify_commit

verify_commit: $(SUBMODULES:%=%-test)
	$(MAKE) -C test verify_commit

$(SUBMODULES:%=%-test_clean):
	$(MAKE) -C $(subst -test_clean,,$@) clean

test_clean:
	$(MAKE) -C test clean

$(SUBMODULES:%=%-flake8):
	$(MAKE) -C $(subst -flake8,,$@) flake8

flake8: $(SUBMODULES:%=%-flake8)
	$(PYTHON) -m flake8 garmindb/*.py garmindb/garmindb/*.py garmindb/summarydb/*.py garmindb/fitbitdb/*.py garmindb/mshealthdb/*.py --max-line-length=180 --ignore=E203,E221,E241,W503

regression_test_run: flake8 rebuild_dbs
	grep ERROR garmin.log || [ $$? -eq 1 ]

regression_test: clean regression_test_run test

PLUGIN_DIR=$(shell $(PYTHON) -c 'from config_manager import ConfigManager; print(ConfigManager.get_plugins_dir())')
publish_plugins:
	cp ./Plugins/*.py $(PLUGIN_DIR)/.

clean_plugins:
	rm $(PLUGIN_DIR)/*.py

republish_plugins: clean_plugins publish_plugins


#
# bugreport target
#
bugreport:
	./bugreport.sh

.PHONY: all setup update deps create_dbs rebuild_dbs update_dbs clean clean_dbs test zip_packages release clean test test_clean daily
