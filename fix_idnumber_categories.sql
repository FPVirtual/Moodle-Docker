-- Fix: Asignar idnumber a las categorías creadas sin -i
-- Ejecutar dentro del contenedor moodle o contra la BD externa.
-- Ejemplo contenedor:
--   docker cp fix_idnumber_categories.sql moodle:/tmp/
--   docker compose exec moodle bash -c "mysql -h\$MOODLE_DB_HOST -u\$MOODLE_DB_USER -p\$MOODLE_DB_PASSWORD \$MOODLE_DB_NAME < /tmp/fix_idnumber_categories.sql"

-- =========================================
-- Categorías raíz (parent = 0)
-- =========================================
UPDATE mdl_course_categories SET idnumber = 'miscelanea'  WHERE parent = 0 AND name = 'Miscelanea';
UPDATE mdl_course_categories SET idnumber = 'general'     WHERE parent = 0 AND name = 'General';
UPDATE mdl_course_categories SET idnumber = 'app'         WHERE parent = 0 AND name = 'NO BORRAR - APP MOVIL';
UPDATE mdl_course_categories SET idnumber = 'sg'          WHERE parent = 0 AND name = 'IES SIERRA DE GUARA';
UPDATE mdl_course_categories SET idnumber = 'se'          WHERE parent = 0 AND name = 'IES SANTA EMERENCIANA';
UPDATE mdl_course_categories SET idnumber = 'tm'          WHERE parent = 0 AND name = 'IES TIEMPOS MODERNOS';
UPDATE mdl_course_categories SET idnumber = 'le'          WHERE parent = 0 AND name = 'CPIFP LOS ENLACES';
UPDATE mdl_course_categories SET idnumber = 'ca'          WHERE parent = 0 AND name = 'CPIFP CORONA DE ARAGÓN';
UPDATE mdl_course_categories SET idnumber = 'pi'          WHERE parent = 0 AND name = 'CPIFP PIRÁMIDE';
UPDATE mdl_course_categories SET idnumber = 'sb'          WHERE parent = 0 AND name = 'CPIFP SAN BLAS';
UPDATE mdl_course_categories SET idnumber = 'mi'          WHERE parent = 0 AND name = 'IES MIRALBUENO';
UPDATE mdl_course_categories SET idnumber = 'ps'          WHERE parent = 0 AND name = 'IES PABLO SERRANO';
UPDATE mdl_course_categories SET idnumber = 'ba'          WHERE parent = 0 AND name = 'CPIFP BAJO ARAGÓN';
UPDATE mdl_course_categories SET idnumber = 'rg'          WHERE parent = 0 AND name = 'IES RÍO GÁLLEGO';
UPDATE mdl_course_categories SET idnumber = 'vt'          WHERE parent = 0 AND name = 'IES VEGA DEL TURIA';
UPDATE mdl_course_categories SET idnumber = 'lb'          WHERE parent = 0 AND name = 'IES LUIS BUÑUEL';
UPDATE mdl_course_categories SET idnumber = 'mo'          WHERE parent = 0 AND name = 'CPIFP MONTEARAGON';
UPDATE mdl_course_categories SET idnumber = 'mv'          WHERE parent = 0 AND name = 'IES MARTÍNEZ VARGAS';
UPDATE mdl_course_categories SET idnumber = 'av'          WHERE parent = 0 AND name = 'IES AVEMPACE';
UPDATE mdl_course_categories SET idnumber = 'mm'          WHERE parent = 0 AND name = 'IES MARÍA MOLINER';
UPDATE mdl_course_categories SET idnumber = 'cd'          WHERE parent = 0 AND name = 'Campus Digital FP';

-- =========================================
-- Subcategorías (identificadas por nombre + padre)
-- =========================================
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'sg_ga'    WHERE cc.name = 'Gestión Administrativa' AND p.name = 'IES SIERRA DE GUARA';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'se_ga'    WHERE cc.name = 'Gestión Administrativa' AND p.name = 'IES SANTA EMERENCIANA';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'tm_ga'    WHERE cc.name = 'Gestión Administrativa' AND p.name = 'IES TIEMPOS MODERNOS';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'le_smr'   WHERE cc.name = 'Sistemas Microinformáticos y Redes' AND p.name = 'CPIFP LOS ENLACES';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'le_ac'    WHERE cc.name = 'Actividades Comerciales' AND p.name = 'CPIFP LOS ENLACES';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'le_ci'    WHERE cc.name = 'Comercio Internacional' AND p.name = 'CPIFP LOS ENLACES';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'le_gvec'  WHERE cc.name = 'Gestión de Ventas y Espacios Comerciales' AND p.name = 'CPIFP LOS ENLACES';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'le_tl'    WHERE cc.name = 'Transporte y Logística' AND p.name = 'CPIFP LOS ENLACES';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'le_daw'   WHERE cc.name = 'Desarrollo de Aplicaciones WEB' AND p.name = 'CPIFP LOS ENLACES';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'le_pae'   WHERE cc.name = 'Producción de Audiovisuales y Espectáculos' AND p.name = 'CPIFP LOS ENLACES';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'ca_ad'    WHERE cc.name = 'Asistencia a la Dirección' AND p.name = 'CPIFP CORONA DE ARAGÓN';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'ca_af'    WHERE cc.name = 'Administración y Finanzas' AND p.name = 'CPIFP CORONA DE ARAGÓN';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'ca_lacc'  WHERE cc.name = 'Laboratorio de Análisis y de Control de Calidad' AND p.name = 'CPIFP CORONA DE ARAGÓN';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'pi_iea'   WHERE cc.name = 'Instalaciones Eléctricas y Automáticas' AND p.name = 'CPIFP PIRÁMIDE';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'sb_eca'   WHERE cc.name = 'Educación y Control Ambiental' AND p.name = 'CPIFP SAN BLAS';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'mi_avge'  WHERE cc.name = 'Agencias de Viajes y Gestión de Eventos' AND p.name = 'IES MIRALBUENO';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'ps_asir'  WHERE cc.name = 'Administración de Sistemas Informáticos en Red' AND p.name = 'IES PABLO SERRANO';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'ba_dam'   WHERE cc.name = 'Desarrollo de Aplicaciones Multiplataforma' AND p.name = 'CPIFP BAJO ARAGÓN';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'rg_sti'   WHERE cc.name = 'Sistemas de Telecomunicaciones e Informáticos' AND p.name = 'IES RÍO GÁLLEGO';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'rg_fp'    WHERE cc.name = 'Farmacia y Parafarmacia' AND p.name = 'IES RÍO GÁLLEGO';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'rg_es'    WHERE cc.name = 'Emergencias Sanitarias' AND p.name = 'IES RÍO GÁLLEGO';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'vt_es'    WHERE cc.name = 'Emergencias Sanitarias' AND p.name = 'IES VEGA DEL TURIA';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'lb_apsd'  WHERE cc.name = 'Atención a Personas en situación de Dependencia' AND p.name = 'IES LUIS BUÑUEL';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'mo_apsd'  WHERE cc.name = 'Atención a Personas en situación de Dependencia' AND p.name = 'CPIFP MONTEARAGON';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'mv_ei'    WHERE cc.name = 'Educación Infantil (Formación Profesional)' AND p.name = 'IES MARTÍNEZ VARGAS';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'av_ei'    WHERE cc.name = 'Educación Infantil (Formación Profesional)' AND p.name = 'IES AVEMPACE';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'mm_is'    WHERE cc.name = 'Integración Social' AND p.name = 'IES MARÍA MOLINER';

UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'cd_smr'   WHERE cc.name = 'Sistemas Microinformáticos y Redes' AND p.name = 'Campus Digital FP';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'cd_asir'  WHERE cc.name = 'Administración de Sistemas Informáticos en Red' AND p.name = 'Campus Digital FP';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'cd_dam'   WHERE cc.name = 'Desarrollo de Aplicaciones Multiplataforma' AND p.name = 'Campus Digital FP';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'cd_daw'   WHERE cc.name = 'Desarrollo de Aplicaciones WEB' AND p.name = 'Campus Digital FP';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'cd_iabd'  WHERE cc.name = 'Inteligencia Artificial y Big Data' AND p.name = 'Campus Digital FP';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'cd_ceti'  WHERE cc.name = 'Ciberseguridad en Entornos de las Tecnologías de la Información' AND p.name = 'Campus Digital FP';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'cd_python' WHERE cc.name = 'Desarrollo de Aplicaciones en Lenguaje Python' AND p.name = 'Campus Digital FP';
UPDATE mdl_course_categories cc JOIN mdl_course_categories p ON p.id = cc.parent SET cc.idnumber = 'cd_nube'  WHERE cc.name = 'Recursos y Servicios en la Nube' AND p.name = 'Campus Digital FP';
