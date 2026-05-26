#!/bin/bash
# Configuración inicial específica para FPVirtual

# Config site
moosh -n config-set forcetimezone Europe/Madrid
moosh -n config-set calendar_site_timeformat %H:%M
moosh -n config-set calendar_startwday 1
moosh -n config-set debugdisplay 0
moosh -n config-set frontpage 6

# Config smtp
echo >&2 "Configuring smtp..."
moosh -n config-set smtphosts ${SMTP_HOSTS}
moosh -n config-set smtpsecure tls
moosh -n config-set smtpauthtype LOGIN
moosh -n config-set smtpuser ${SMTP_USER}
moosh -n config-set smtppass ${SMTP_PASSWORD}
moosh -n config-set smtpmaxbulk ${SMTP_MAXBULK}
moosh -n config-set noreplyaddress ${NO_REPLY_ADDRESS}

# Authentication
moosh -n config-set authloginviaemail 0
moosh -n config-set allowguestmymoodle 0
moosh -n config-set allowaccountssameemail 1
moosh -n config-set guestloginbutton 0

# Licenses
moosh -n config-set sitedefaultlicense cc-nc-sa

# Config webservices
echo >&2 "Configuring webservices..."
moosh -n config-set enablewebservices 1
moosh -n config-set enablemobilewebservice 1

# Config blog
echo >&2 "Configuring blog..."
moosh -n config-set enableblogs 1

# Set languages
echo >&2 "Configuring languages..."
moosh -n lang-install es
moosh -n config-set doclang es
moosh -n config-set lang es
moosh -n config-set country ES
moosh -n config-set timezone Europe/Madrid

# Config navigation
echo >&2 "Configuring navigation..."
moosh -n config-set defaulthomepage 0
moosh -n config-set searchincludeallcourses 1
moosh -n config-set navshowfullcoursenames 1
moosh -n config-set navshowcategories 0
moosh -n config-set navshowallcourses 1
moosh -n config-set navsortmycoursessort idnumber
moosh -n config-set navcourselimit 20
moosh -n config-set linkadmincategories 0
moosh -n config-set linkcoursesections 0
moosh -n config-set navshowfrontpagemods 0
moosh -n config-set frontpageloggedin 5,0

# Enable cron through web browser
echo >&2 "Configuring cron through web browser..."
moosh -n config-set cronremotepassword ${CRON_BROWSER_PASS}
moosh -n config-set cronclionly 0

# Badges config
echo >&2 "Configuring badges..."
moosh -n config-set badges_defaultissuercontact ${MOODLE_ADMIN_EMAIL}
moosh -n config-set badges_defaultissuername "Plataforma FP Virtual"

# Users config
echo >&2 "Configuring users..."
moosh -n config-set enablegravatar 1
moosh -n config-set enableportfolios 1
moosh -n config-set defaultpreference_maildisplay 0
moosh -n config-set defaultpreference_maildigest 2
moosh -n config-set defaultpreference_trackforums 1
moosh -n config-set hiddenuserfields email
moosh -n config-set showuseridentity username
moosh -n config-set block_online_users_timetosee 10

# statistics
moosh -n config-set enablestats 1

# feeds
moosh -n config-set enablerssfeeds 1

# courses
moosh -n config-set enableglobalsearch 1
moosh -n config-set enablecourserequests 1
moosh -n config-set courserequestnotify \$\@ALL@$
moosh -n config-set searchincludeallcourses 0
moosh -n config-set courseenddateenabled 0 moodlecourse
moosh -n config-set format topics moodlecourse

# Completion
moosh -n config-set completiondefault 0

# assign
moosh -n config-set enabletimelimit 1 assign
moosh -n config-set duedate_enabled '' assign
moosh -n config-set cutoffdate_enabled '' assign
moosh -n config-set gradingduedate_enabled '' assign

# grades
moosh -n config-set gradeexport ods,txt,xml
moosh -n config-set gradepointmax 10
moosh -n config-set grade_aggregation 10
moosh -n config-set grade_aggregations_visible 0,10,13
moosh -n config-set grade_report_showquickfeedback 1
moosh -n config-set grade_report_user_rangedecimals 2
moosh -n config-set gradepointdefault 10

# themes
moosh -n config-set allowthemechangeonurl 1

# Site Policyhandler
moosh -n config-set sitepolicyhandler tool_policy
moosh -n config-set contactdataprotectionofficer 1 tool_dataprivacy
moosh -n config-set showdataretentionsummary 0 tool_dataprivacy

# Para FPD no se crean gestorae ni asesoria ni familiar

#Updates made at the beginning of the course
moosh -n sql-run "INSERT INTO mdl_scale (name, scale, description) VALUES('Aptitud','No apta, Apta','Escala FPD')"

echo >&2 "set value of max_file_size by default in courses"
moosh -n config-set maxbytes 201326592

echo >&2 "Blocking firstname and lastname edition"
moosh -n config-set field_lock_firstname unlockedifempty auth_manual
moosh -n config-set field_lock_lastname unlockedifempty auth_manual

echo >&2 "Blocking guest users watching forum messages"
moosh -n role-update-capability guest mod/forum:viewdiscussion prohibit 1

#Update default notification configuration for users
# (solo las notificaciones que aplica a FPD, simplificado)
echo >&2 "Updating default notification preferences"
moosh -n config-set message_provider_mod_assign_assign_notification_loggedin popup,airnotifier message
moosh -n config-set message_provider_mod_assign_assign_notification_loggedoff popup,airnotifier message
moosh -n config-set message_provider_mod_forum_posts_loggedin popup,airnotifier message
moosh -n config-set message_provider_mod_forum_posts_loggedoff popup,airnotifier message
moosh -n config-set message_provider_moodle_instantmessage_loggedin popup,airnotifier message
moosh -n config-set message_provider_moodle_instantmessage_loggedoff popup,airnotifier message

# Para FPD quitar insignias
moosh -n config-set enablebadges 0

# Quitamos analítica
moosh -n config-set enableanalytics 0

# Set specific configuration for FPD
# duplicate activities
moosh -n role-update-capability teacher moodle/restore:restoretargetimport allow 1
moosh -n role-update-capability teacher moodle/backup:backuptargetimport allow 1
# avoid changing short name, used for automations
moosh -n role-update-capability teacher moodle/course:changeshortname prohibit 1
moosh -n role-update-capability teacher moodle/course:changefullname prohibit 1
# avoid access to repositories
moosh -n role-update-capability teacher repository/contentbank:accessgeneralcontent prohibit 1
# avoid manual unenrolments for teachers
moosh -n role-update-capability teacher enrol/cohort:config prohibit 1
moosh -n role-update-capability teacher enrol/database:config prohibit 1
moosh -n role-update-capability teacher enrol/guest:config prohibit 1
moosh -n role-update-capability teacher enrol/imsenterprise:config prohibit 1
moosh -n role-update-capability teacher enrol/lti:unenrol prohibit 1
moosh -n role-update-capability teacher enrol/manual:unenrol prohibit 1
moosh -n role-update-capability teacher enrol/paypal:manage prohibit 1
moosh -n role-update-capability teacher enrol/self:config prohibit 1
moosh -n role-update-capability teacher enrol/self:unenrol prohibit 1
moosh -n role-update-capability teacher enrol/fee:manage prohibit 1
moosh -n role-update-capability teacher enrol/manual:manage prohibit 1
moosh -n role-update-capability teacher enrol/cohort:unenrol prohibit 1
moosh -n role-update-capability teacher enrol/manual:unenrolself prohibit 1

echo >&2 "Updating default HTTP configuration"
moosh -n config-set getremoteaddrconf 1

echo >&2 "Activating Messaging in Moodle general configuration"
moosh -n config-set messaging 1

echo >&2 "Activating Mobile configuration for push notifications"
moosh -n config-set airnotifierurl "https://bma.messages.moodle.net"
moosh -n config-set airnotifiermobileappname "es.aragon.fpdistancia"
moosh -n config-set airnotifierappname "esaragonfpdistancia"
moosh -n config-set airnotifieraccesskey "1e6698fd71bad502044c09a4f547f65c"

#Habilitar actividades sigilosas
echo >&2 "Activating allowstealth activities"
moosh -n config-set allowstealth 1

#Habilitar MoodleNet
echo >&2 "Activating MoodleNet"
moosh -n config-set enablemoodlenet 1 tool_moodlenet
moosh -n config-set activitychooseractivefooter tool_moodlenet

#Habilitar descarga de curso
echo >&2 "Activating Course Content Download"
moosh -n config-set downloadcoursecontentallowed 1

echo >&2 "moodle.sh done"
