#!/bin/bash
# Configuración inicial específica para FPD

# Config site
moosh config-set forcetimezone Europe/Madrid
moosh config-set calendar_site_timeformat %H:%M
moosh config-set calendar_startwday 1
moosh config-set debugdisplay 0
moosh config-set frontpage 6

# Config smtp
echo >&2 "Configuring smtp..."
moosh config-set smtphosts ${SMTP_HOSTS}
moosh config-set smtpsecure tls
moosh config-set smtpauthtype LOGIN
moosh config-set smtpuser ${SMTP_USER}
moosh config-set smtppass ${SMTP_PASSWORD}
moosh config-set smtpmaxbulk ${SMTP_MAXBULK}
moosh config-set noreplyaddress ${NO_REPLY_ADDRESS}

# Authentication
moosh config-set authloginviaemail 0
moosh config-set allowguestmymoodle 0
moosh config-set allowaccountssameemail 1
moosh config-set guestloginbutton 0

# Licenses
moosh config-set sitedefaultlicense cc-nc-sa

# Config webservices
echo >&2 "Configuring webservices..."
moosh config-set enablewebservices 1
moosh config-set enablemobilewebservice 1

# Config blog
echo >&2 "Configuring blog..."
moosh config-set enableblogs 1

# Set languages
echo >&2 "Configuring languages..."
moosh lang-install es
moosh config-set doclang es
moosh config-set lang es
moosh config-set country ES
moosh config-set timezone Europe/Madrid

# Config navigation
echo >&2 "Configuring navigation..."
moosh config-set defaulthomepage 0
moosh config-set searchincludeallcourses 1
moosh config-set navshowfullcoursenames 1
moosh config-set navshowcategories 0
moosh config-set navshowallcourses 1
moosh config-set navsortmycoursessort idnumber
moosh config-set navcourselimit 20
moosh config-set linkadmincategories 0
moosh config-set linkcoursesections 0
moosh config-set navshowfrontpagemods 0
moosh config-set frontpageloggedin 5,0

# Enable cron through web browser
echo >&2 "Configuring cron through web browser..."
moosh config-set cronremotepassword ${CRON_BROWSER_PASS}
moosh config-set cronclionly 0

# Badges config
echo >&2 "Configuring badges..."
moosh config-set badges_defaultissuercontact ${MOODLE_ADMIN_EMAIL}
moosh config-set badges_defaultissuername "Plataforma FP Virtual"

# Users config
echo >&2 "Configuring users..."
moosh config-set enablegravatar 1
moosh config-set enableportfolios 1
moosh config-set defaultpreference_maildisplay 0
moosh config-set defaultpreference_maildigest 2
moosh config-set defaultpreference_trackforums 1
moosh config-set hiddenuserfields email
moosh config-set showuseridentity username
moosh config-set block_online_users_timetosee 10

# statistics
moosh config-set enablestats 1

# feeds
moosh config-set enablerssfeeds 1

# courses
moosh config-set enableglobalsearch 1
moosh config-set enablecourserequests 1
moosh config-set courserequestnotify \$\@ALL@$
moosh config-set searchincludeallcourses 0
moosh config-set courseenddateenabled 0 moodlecourse
moosh config-set format topics moodlecourse

# Completion
moosh config-set completiondefault 0

# assign
moosh config-set enabletimelimit 1 assign
moosh config-set duedate_enabled '' assign
moosh config-set cutoffdate_enabled '' assign
moosh config-set gradingduedate_enabled '' assign

# grades
moosh config-set gradeexport ods,txt,xml
moosh config-set gradepointmax 10
moosh config-set grade_aggregation 10
moosh config-set grade_aggregations_visible 0,10,13
moosh config-set grade_report_showquickfeedback 1
moosh config-set grade_report_user_rangedecimals 2
moosh config-set gradepointdefault 10

# themes
moosh config-set allowthemechangeonurl 1

# Site Policyhandler
moosh config-set sitepolicyhandler tool_policy
moosh config-set contactdataprotectionofficer 1 tool_dataprivacy
moosh config-set showdataretentionsummary 0 tool_dataprivacy

# Para FPD no se crean gestorae ni asesoria ni familiar

#Updates made at the beginning of the course
moosh sql-run "INSERT INTO mdl_scale (name, scale, description) VALUES('Aptitud','No apta, Apta','Escala FPD')"

echo >&2 "Creando usuarios estudiantes del 1 al 10"
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante1" --lastname "Uno" estudiante1
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante2" --lastname "Dos" estudiante2
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante3" --lastname "Tres" estudiante3
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante4" --lastname "Cuatro" estudiante4
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante5" --lastname "Cinco" estudiante5
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante6" --lastname "Seis" estudiante6
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante7" --lastname "Siete" estudiante7
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante8" --lastname "Ocho" estudiante8
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante9" --lastname "Nueve" estudiante9
moosh user-create --password estudiante --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname "Estudiante10" --lastname "Diez" estudiante10

echo >&2 "set value of max_file_size by default in courses"
moosh config-set maxbytes 201326592

echo >&2 "Blocking firstname and lastname edition"
moosh config-set field_lock_firstname unlockedifempty auth_manual
moosh config-set field_lock_lastname unlockedifempty auth_manual

echo >&2 "Blocking guest users watching forum messages"
moosh role-update-capability guest mod/forum:viewdiscussion prohibit 1

#Update default notification configuration for users
# (solo las notificaciones que aplica a FPD, simplificado)
echo >&2 "Updating default notification preferences"
moosh config-set message_provider_mod_assign_assign_notification_loggedin popup,airnotifier message
moosh config-set message_provider_mod_assign_assign_notification_loggedoff popup,airnotifier message
moosh config-set message_provider_mod_forum_posts_loggedin popup,airnotifier message
moosh config-set message_provider_mod_forum_posts_loggedoff popup,airnotifier message
moosh config-set message_provider_moodle_instantmessage_loggedin popup,airnotifier message
moosh config-set message_provider_moodle_instantmessage_loggedoff popup,airnotifier message

# Para FPD quitar insignias
moosh config-set enablebadges 0

# Quitamos analítica
moosh config-set enableanalytics 0

# Set specific configuration for FPD
# duplicate activities
moosh role-update-capability teacher moodle/restore:restoretargetimport allow 1
moosh role-update-capability teacher moodle/backup:backuptargetimport allow 1
# avoid changing short name, used for automations
moosh role-update-capability teacher moodle/course:changeshortname prohibit 1
moosh role-update-capability teacher moodle/course:changefullname prohibit 1
# avoid access to repositories
moosh role-update-capability teacher repository/contentbank:accessgeneralcontent prohibit 1
# avoid manual unenrolments for teachers
moosh role-update-capability teacher enrol/cohort:config prohibit 1
moosh role-update-capability teacher enrol/database:config prohibit 1
moosh role-update-capability teacher enrol/guest:config prohibit 1
moosh role-update-capability teacher enrol/imsenterprise:config prohibit 1
moosh role-update-capability teacher enrol/lti:unenrol prohibit 1
moosh role-update-capability teacher enrol/manual:unenrol prohibit 1
moosh role-update-capability teacher enrol/paypal:manage prohibit 1
moosh role-update-capability teacher enrol/self:config prohibit 1
moosh role-update-capability teacher enrol/self:unenrol prohibit 1
moosh role-update-capability teacher enrol/fee:manage prohibit 1
moosh role-update-capability teacher enrol/manual:manage prohibit 1
moosh role-update-capability teacher enrol/cohort:unenrol prohibit 1
moosh role-update-capability teacher enrol/manual:unenrolself prohibit 1

echo >&2 "Updating default HTTP configuration"
moosh config-set getremoteaddrconf 1

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
