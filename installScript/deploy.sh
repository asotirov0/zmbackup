#!/bin/bash
################################################################################

################################################################################
# blacklist_gen: Generate a blacklist of all accounts Zmbackup should ignore
################################################################################
function blacklist_gen(){
  for ACCOUNT in $(sudo -H -u $OSE_USER bash -c "/opt/zimbra/bin/zmprov -l gaa"); do
    if  [[ "$ACCOUNT" = "galsync"* ]] || \
    [[ "$ACCOUNT" = "virus"* ]] || \
    [[ "$ACCOUNT" = "ham"* ]] || \
    [[ "$ACCOUNT" = "admin"* ]] || \
    [[ "$ACCOUNT" = "spam"* ]] || \
    [[ "$ACCOUNT" = "zmbackup"* ]] || \
    [[ "$ACCOUNT" = "postmaster"* ]] || \
    [[ "$ACCOUNT" = "root"* ]]; then
      echo $ACCOUNT >> $ZMBKP_CONF/blacklist.conf
    fi
  done
  echo $ZMBKP_ACCOUNT >> $ZMBKP_CONF/blacklist.conf
}

################################################################################
# deploy_new: Deploy a new version of Zmbackup
################################################################################
function deploy_new() {
  echo "Installing... Please wait while we made some changes."
  echo -ne '                      (0%)\r'
  mkdir $OSE_DEFAULT_BKP_DIR > /dev/null 2>&1 && chown $OSE_USER.$OSE_USER $OSE_DEFAULT_BKP_DIR > /dev/null 2>&1
  echo -ne '#                     (5%)\r'
  test -d $ZMBKP_CONF || mkdir -p $ZMBKP_CONF
  echo -ne '##                    (10%)\r'
  test -d $ZMBKP_SRC  || mkdir -p $ZMBKP_SRC
  echo -ne '###                   (15%)\r'
  test -d $ZMBKP_SHARE || mkdir -p $ZMBKP_SHARE
  test -d $ZMBKP_LIB || mkdir -p $ZMBKP_LIB
  echo -ne '####                  (20%)\r'

  # Disable Parallel's message - Zmbackup remind the user about GNU Parallel
  mkdir $OSE_INSTALL_DIR/.parallel && touch $OSE_INSTALL_DIR/.parallel/will-cite
  chown -R zimbra. $OSE_INSTALL_DIR/.parallel

  # Copy file
  install -o $OSE_USER -m 700 $MYDIR/project/zmbackup $ZMBKP_SRC
  echo -ne '#####                 (25%)\r'
  cp -R $MYDIR/project/lib/* $ZMBKP_LIB
  chown -R $OSE_USER. $ZMBKP_LIB
  chmod -R 700 $ZMBKP_LIB
  echo -ne '######                (30%)\r'
  install --backup=numbered -o root -m 600 $MYDIR/project/config/zmbackup.cron /etc/cron.d
  echo -ne '#######               (35%)\r'
  install --backup=numbered -o $OSE_USER -m 600 $MYDIR/project/config/zmbackup.conf $ZMBKP_CONF
  echo -ne '########              (40%)\r'
  install --backup=numbered -o $OSE_USER -m 600 $MYDIR/project/config/blacklist.conf $ZMBKP_CONF
  echo -ne '#########             (45%)\r'

  # Including custom settings
  sed -i "s|{OSE_DEFAULT_BKP_DIR}|${OSE_DEFAULT_BKP_DIR}|g" $ZMBKP_CONF/zmbackup.conf
  echo -ne '##########            (50%)\r'
  sed -i "s|{ZMBKP_ACCOUNT}|${ZMBKP_ACCOUNT}|g" $ZMBKP_CONF/zmbackup.conf
  echo -ne '###########           (55%)\r'
  sed -i "s|{ZMBKP_PASSWORD}|${ZMBKP_PASSWORD}|g" $ZMBKP_CONF/zmbackup.conf
  echo -ne '############          (60%)\r'
  sed -i "s|{ZMBKP_MAIL_ALERT}|${ZMBKP_MAIL_ALERT}|g" $ZMBKP_CONF/zmbackup.conf
  echo -ne '#############         (65%)\r'
  sed -i "s|{OSE_INSTALL_ADDRESS}|${OSE_INSTALL_ADDRESS}|g" $ZMBKP_CONF/zmbackup.conf
  echo -ne '##############        (70%)\r'
  sed -i "s|{OSE_INSTALL_LDAPPASS}|${OSE_INSTALL_LDAPPASS}|g" $ZMBKP_CONF/zmbackup.conf
  sed -i "s|{SESSION_TYPE}|${SESSION_TYPE}|g" $ZMBKP_CONF/zmbackup.conf
  echo -ne '###############       (75%)\r'
  sed -i "s|{OSE_USER}|${OSE_USER}|g" $ZMBKP_CONF/zmbackup.conf
  sed -i "s|{MAX_PARALLEL_PROCESS}|${MAX_PARALLEL_PROCESS}|g" $ZMBKP_CONF/zmbackup.conf
  echo -ne '################      (80%)\r'
  sed -i "s|{ROTATE_TIME}|${ROTATE_TIME}|g" $ZMBKP_CONF/zmbackup.conf
  sed -i "s|{LOCK_BACKUP}|${LOCK_BACKUP}|g" $ZMBKP_CONF/zmbackup.conf
  echo -ne '#################     (85%)\r'

  # Fix backup dir permissions (owner MUST be $OSE_USER)
  chown $OSE_USER $OSE_DEFAULT_BKP_DIR
  echo -ne '##################    (90%)\r'

  # Generate Zmbackup's blacklist
  blacklist_gen
  echo -ne '###################   (95%)\r'

  # Creating Zmbackup backup user
  sudo -H -u $OSE_USER bash -c "/opt/zimbra/bin/zmprov ca '$ZMBKP_ACCOUNT' '$ZMBKP_PASSWORD' zimbraIsAdminAccount TRUE zimbraAdminAuthTokenLifetime 1" > /dev/null 2>&1
  echo -ne '####################  (100%)\r'
}

################################################################################
# deploy_upgrade: Upgrade the old version to the new one
################################################################################
function deploy_upgrade(){
  # Removing old version
  echo "Upgrading... Please wait while we made some changes."
  echo -ne '                     (0%)\r'
  rm -rf $ZMBKP_SHARE $ZMBKP_SRC/zmbhousekeep > /dev/null 2>&1
  echo -ne '##########            (50%)\r'

  # Disable Parallel's message - Zmbackup remind the user about GNU Parallel
  mkdir $OSE_INSTALL_DIR/.parallel && touch $OSE_INSTALL_DIR/.parallel/will-cite
  chown -R zimbra. $OSE_INSTALL_DIR/.parallel

  # Copy files
  install -o $OSE_USER -m 700 $MYDIR/project/zmbackup $ZMBKP_SRC
  echo -ne '###############       (75%)\r'
  test -d $ZMBKP_LIB || mkdir -p $ZMBKP_LIB
  cp -R $MYDIR/project/lib/* $ZMBKP_LIB
  chown -R $OSE_USER. $ZMBKP_LIB
  chmod -R 700 $ZMBKP_LIB
  echo -ne '####################  (100%)\r'
}

################################################################################
# uninstall: Remove zmbackup, their dependencies, and all files related
################################################################################
function uninstall() {
  echo "Removing... Please wait while we made some changes."
  echo -ne '                     (0%)\r'
  rm -rf $ZMBKP_SHARE $ZMBKP_SRC/zmbhousekeep > /dev/null 2>&1
  rm -rf $OSE_INSTALL_DIR/.parallel
  echo -ne '#####                 (25%)\r'
  rm -rf $ZMBKP_LIB $ZMBKP_CONF $ZMBKP_SRC/zmbackup
  echo -ne '##########            (50%)\r'
  if [[ -f $ZMBKP_CONF/blacklist.conf ]]; then
    install --backup=numbered -o $OSE_USER -m 600 $MYDIR/project/config/blacklist.conf $ZMBKP_CONF
    blacklist_gen
  fi
  echo -ne '###############       (75%)\r'
  sudo -H -u $OSE_USER bash -c "/opt/zimbra/bin/zmprov da $ZMBKP_ACCOUNT" > /dev/null 2>&1
  echo -ne '####################  (100%)\r'
}
