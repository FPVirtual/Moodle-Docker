<?php
require_once(__DIR__ . '/../config.php');
global $CFG, $USER, $DB;

// Comprobar si el usuario está logueado en Moodle
require_login();

echo '<!doctype html>';
echo '<html lang="es">';
echo '<head>';
echo '<meta charset="utf-8">';
echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
echo '<title>Informes jefaturas de estudios</title>';
echo '<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-T3c6CoIi6uLrA9TneNEoa7RxnatzjcDSCmG1MXxSR1GAsXEV/Dwwykc2MPK8M2HN" crossorigin="anonymous">';
echo '</head>';
echo '<body>';
echo "<a name='arriba'></a>";
echo '<div class="container">';
echo "<h1>Informes para jefaturas de estudios</h1>";


// Obtener el id de la categoría  de la jefatura de estudios

$courses = $DB->get_records_sql("
    select concat(name, ' - ', description) label
    FROM {course_categories} cc
    where path like ( 
        select concat('/', data, '/%')
        from {user_info_data}
        where fieldid = 1 and userid = ?
    )", 
    array($USER->id));

if (empty($courses)) {
    echo "El usuario " . $USER->id . " no tiene jefaturas asignadas";
    die();
}

// Si se ha enviado el formulario, obtener el curso
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $courseid = required_param('courseid', PARAM_INT);
    //$course = $DB->get_record('course', array('id' => $courseid), '*', MUST_EXIST);
}

// Formulario con la lista de cursos en que el usuario tiene el rol de profesor
echo "<form method='post' action='jefaturas.php' >";
echo "<select name='courseid'>";
foreach ($courses as $c) {
    $selected = ($c->id == $courseid) ? 'selected' : '';
    echo "<option value='$c->id' $selected>$c->label</option>";
}
echo "</select>";
echo "<input type='submit' value='Buscar'>";
echo "</form>";
echo "<hr/>";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {


    echo "<a href='#j1'>JE - Estudiantes activos que nunca han accedido</a><br/>";
    echo "<a href='#j2'>JE - Estudiantes activos que nunca han accedido al curso</a><br/>";
    echo "<a href='#j3'>JE - Estudiantes con entre 5 y 10 días sin acceder a un curso</a><br/>";
    echo "<a href='#j4'>JE - Estudiantes que hace mas de 10 días no acceden a un curso</a><br/>";
    echo "<a href='#j5'>JE - Prof que hace 7 días o mas que no se conecta a Moodle</a><br/>";
    echo "<a href='#j6'>JE - Profesores que hace 7 dias o mas no acceden a un curso</a><br/>";
    echo "<a href='#j7'>JE - Sesiones de videoconferencia</a><br/>";
    echo "<hr/>";
    /***********************************************/
    // JE - Estudiantes activos que nunca han accedido
    /***********************************************/
    $estudiantes = $DB->get_records_sql("
    select 
        RAND(),
        u.id uid,
        u.lastname,
        u.firstname,
        c.id cid,
        c.fullname,
        DATE_FORMAT(FROM_UNIXTIME(ue.timecreated), '%Y-%m-%d %H:%i') matriculado_el
        , u.email
        , uid.data
    from {user_enrolments} ue
        join {user} as u on u.id = ue.userid
        join {enrol} e on e.id = ue.enrolid
        join {course} c on c.id = e.courseid
        join {user_info_data} uid on u.id = uid.userid
    where ue.status = 0
        -- filtro para las jefaturas
        and c.id in (
            SELECT id 
            FROM {course}
            where category in (
                select id 
                from {course_categories}
                where path like (
                    SELECT concat('/',data,'/%')  
                    FROM {user_info_data}
                    where fieldid = 1 and userid = ?
                )
            )
        )
        -- fin de filtro para las jefaturas
        and uid.fieldid = 4
        and ue.enrolid in 
            (select e.id
            from {enrol} e 
            where e.courseid in (
                SELECT id 
                FROM {course}
                where category in (
                    select id 
                    from {course_categories}
                    where path like (
                        SELECT concat('/',data,'/%')  
                        FROM {user_info_data}
                        where fieldid = 1 and userid = ?
                    )
                )
        )
            )
        and ue.userid not in (select userid from {user_lastaccess} where courseid = c.id)
    order by u.lastname, u.firstname, c.fullname
    ", array($USER->id, $USER->id));
    
    // Mostrar los JE - Estudiantes activos que nunca han accedido
    echo "<a name='j1'></a>";
    echo "<h2>JE - Estudiantes activos que nunca han accedido <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th class='th-sm'>Nombre</th><th class='th-sm'>Email plataforma</th><th class='th-sm'>Email SIGAD</th><th class='th-sm'>Matriculado en</th><th class='th-sm'>Matriculado el</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->uid}' target='_blank'>{$s->firstname} {$s->lastname}</a>";
        echo     " <a href='{$CFG->wwwroot}/message/index.php?id={$s->uid}' target='_blank'><svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='currentColor' class='bi bi-chat-left-dots' viewBox='0 0 16 16'>
        <path d='M14 1a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H4.414A2 2 0 0 0 3 11.586l-2 2V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12.793a.5.5 0 0 0 .854.353l2.853-2.853A1 1 0 0 1 4.414 12H14a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z'/>
        <path d='M5 6a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0z'/> (mensaje)</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->email}</td>";
        echo   "<td style='text-align:right;'>{$s->data}</td>";
        echo   "<td>{$s->fullname}</td>";
        echo   "<td style='text-align:right;'>{$s->matriculado_el}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

    /****************************************************************************/
    // Obtener los JE - Estudiantes activos que nunca han accedido al curso
    /****************************************************************************/
    $estudiantes = $DB->get_records_sql("
    select 
        RAND(),
        u.id,
        u.lastname,
        u.firstname,
        DATE_FORMAT(FROM_UNIXTIME(ue.timecreated), '%Y-%m-%d %H:%i') matriculado_el
        , u.email
        , uid.data
    from {user_enrolments} ue
        join {user} u on u.id = ue.userid
        join {enrol} e on e.id = ue.enrolid
        join {course} c on c.id = e.courseid
        join {user_info_data} uid on u.id = uid.userid
    where ue.status = 0
        -- filtro para las jefaturas
        and c.id in (
            SELECT id 
            FROM {course}
            where category in (
                select id 
                from {course_categories} 
                where path like (
                SELECT concat('/',data,'/%')  
                FROM {user_info_data} 
                where fieldid = 1 and userid = ?
                )
            )
        )
        -- fin de filtro para las jefaturas
        and uid.fieldid = 4
        and ue.enrolid in 
            (select e.id
            from {enrol} e 
            where e.courseid = ?
            )
        and ue.userid not in (select userid from {user_lastaccess} where courseid = ?)
    order by u.lastname, u.firstname
    ", array($USER->id, $courseid, $courseid));

    // Mostrar los JE - Estudiantes activos que nunca han accedido al curso
    echo "<a name='j2'></a>";
    echo "<h2>JE - Estudiantes activos que nunca han accedido al curso <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th>Nombre</th><th class='th-sm'>Email plataforma</th><th class='th-sm'>Email SIGAD</th><th>matriculado_el</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->id}' target='_blank'>{$s->firstname} {$s->lastname}</a>";
        echo     " <a href='{$CFG->wwwroot}/message/index.php?id={$s->id}' target='_blank'><svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='currentColor' class='bi bi-chat-left-dots' viewBox='0 0 16 16'>
        <path d='M14 1a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H4.414A2 2 0 0 0 3 11.586l-2 2V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12.793a.5.5 0 0 0 .854.353l2.853-2.853A1 1 0 0 1 4.414 12H14a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z'/>
        <path d='M5 6a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0z'/> (mensaje)</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->email}</td>";
        echo   "<td style='text-align:right;'>{$s->data}</td>";
        echo   "<td style='text-align:right;'>{$s->matriculado_el}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

    /********************************************************************************/
    // Obtener los JE - Estudiantes con entre 5 y 10 días sin acceder a un curso
    /********************************************************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        RAND(),
        u.id uid,
        u.lastname,
        u.firstname,
        c.id cid,
        c.fullname,
        DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%d-%m-%Y %H:%i') as ult_acceso, 
        DATE_FORMAT(now(), '%d-%m-%Y %H:%i') as hoy,
        DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1) as dias_entre_ult_acceso_y_hoy
        , u.email
        , uid.data
    FROM {user_lastaccess} la
        join {user} u on u.id = la.userid
        join {course} c on c.id = la.courseid
        join {user_enrolments} ue on ue.userid = u.id
        join {user_info_data} uid on u.id = uid.userid
    where u.username not like 'prof%' 
        and ((DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) > 4)
        and ((DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) < 10)
        -- filtro para las jefaturas
        and c.id in (
            SELECT id 
            FROM {course}
            where category in (
                select id 
                from {course_categories}
                where path like (
                SELECT concat('/',data,'/%')  
                FROM {user_info_data}
                where fieldid = 1 and userid = ?
                )
            )
        )
        -- fin de filtro para las jefaturas
        and uid.fieldid = 4
        and ue.enrolid in 
                        (select e.id
                        from {enrol} e 
                        where e.courseid = c.id )
        and ue.status = 0 -- activo: 0 suspendido: 1
    order by u.lastname, u.firstname, c.fullname
    ", array($USER->id));

    // Mostrar los JE - Estudiantes con entre 5 y 10 días sin acceder a un curso
    echo "<a name='j3'></a>";
    echo "<h2>JE - Estudiantes con entre 5 y 10 días sin acceder a un curso <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th>#</th><th>Nombre</th><th class='th-sm'>Email plataforma</th><th class='th-sm'>Email SIGAD</th><th>Curso</th><th>Último acceso</th><th>Hoy</th><th>Días entre</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    $i = 0;
    foreach ($estudiantes as $s) {
        $i++;
        echo "<tr>";
        echo   "<td>{$i}</td>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->uid}' target='_blank'>{$s->firstname} {$s->lastname}</a>";
        echo     " <a href='{$CFG->wwwroot}/message/index.php?id={$s->uid}' target='_blank'><svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='currentColor' class='bi bi-chat-left-dots' viewBox='0 0 16 16'>
        <path d='M14 1a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H4.414A2 2 0 0 0 3 11.586l-2 2V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12.793a.5.5 0 0 0 .854.353l2.853-2.853A1 1 0 0 1 4.414 12H14a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z'/>
        <path d='M5 6a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0z'/> (mensaje)</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->email}</td>";
        echo   "<td style='text-align:right;'>{$s->data}</td>";
        echo   "<td>{$s->fullname}</td>";
        echo   "<td style='text-align:right;'>{$s->ult_acceso}</td>";
        echo   "<td style='text-align:right;'>{$s->hoy}</td>";
        echo   "<td style='text-align:right;'>{$s->dias_entre_ult_acceso_y_hoy}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

    /***********************************************/
    // JE - Estudiantes que hace mas de 10 días no acceden a un cur
    /***********************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        RAND(),
        u.id uid,
        u.lastname,
        u.firstname,
        c.id cid,
        c.fullname cfullname,
        DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%d-%m-%Y %H:%i') as ult_acceso, 
        DATE_FORMAT(now(), '%d-%m-%Y %H:%i') as hoy,
        DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1) as dias_entre_ult_acceso_y_hoy
        , u.email
        , uid.data
    FROM {user_lastaccess} la
        join {user} u on u.id = la.userid
        join {course} c on c.id = la.courseid
        join {user_enrolments} ue on ue.userid = u.id
        join {user_info_data} uid on u.id = uid.userid
    where u.username not like 'prof%' 
        and ((DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) > 10)	
        -- filtro para las jefaturas
        and c.id in (
            SELECT id 
            FROM {course}
            where category in (
                select id 
                from {course_categories}
                where path like (
                SELECT concat('/',data,'/%')  
                FROM {user_info_data} 
                where fieldid = 1 and userid = ?
                )
            )
        )
        -- fin de filtro para las jefaturas
        and uid.fieldid = 4
        and ue.enrolid in 
                        (select e.id
                        from {enrol} e 
                        where e.courseid = c.id
                            )
        and ue.status = 0 -- activo: 0 suspendido: 1
        and c.shortname not like '%t'
    order by u.lastname, u.firstname, c.fullname
    ", [$USER->id]);

    // Mostrar JE - Estudiantes que hace mas de 10 días no acceden a un curso
    echo "<a name='j4'></a>";
    echo "<h2>JE - Estudiantes que hace mas de 10 días no acceden a un curso <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th>#</th><th>Nombre</th><th class='th-sm'>Email plataforma</th><th class='th-sm'>Email SIGAD</th><th>Curso</th><th>Último acceso</th><th>Hoy</th><th>Dias entre</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    $i = 0;
    foreach ($estudiantes as $s) {
        $i++;
        echo "<tr>";
        echo   "<td>{$i}</td>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->uid}' target='_blank'>{$s->firstname} {$s->lastname}</a>";
        echo     " <a href='{$CFG->wwwroot}/message/index.php?id={$s->uid}' target='_blank'><svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='currentColor' class='bi bi-chat-left-dots' viewBox='0 0 16 16'>
        <path d='M14 1a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H4.414A2 2 0 0 0 3 11.586l-2 2V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12.793a.5.5 0 0 0 .854.353l2.853-2.853A1 1 0 0 1 4.414 12H14a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z'/>
        <path d='M5 6a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0z'/> (mensaje)</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->email}</td>";
        echo   "<td style='text-align:right;'>{$s->data}</td>";
        echo   "<td>{$s->cfullname}</td>";
        echo   "<td style='text-align:right;'>{$s->ult_acceso}</td>";
        echo   "<td style='text-align:right;'>{$s->hoy}</td>";
        echo   "<td style='text-align:right;'>{$s->dias_entre_ult_acceso_y_hoy}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";


    /********************************************************************************/
    // JE - Prof que hace 7 días o mas que no se conecta a Moodle
    /********************************************************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        RAND(),
        u.id,
        lastname,
        u.firstname,
        cc.name as ciclo,
        (select ccc.name from {course_categories} as ccc where ccc.id = SUBSTRING_INDEX(SUBSTRING(cc.path, 2), '/', 1  ) ) as centro,
        DATE_FORMAT(FROM_UNIXTIME(lastaccess), '%d-%m-%Y %H:%i') as ult_acceso,
        DATE_FORMAT(now(), '%d-%m-%Y %H:%i') as hoy,
        DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(lastaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1) as dias_entre_ult_acceso_y_hoy
        , u.email
        , uid.data
    FROM {user} u
        join {user_enrolments} ue on ue.userid = u.id
        join {enrol} e on e.id = ue.enrolid
        join {course} c on c.id = e.courseid
        join {course_categories} cc on c.category = cc.id
        join {user_info_data} uid on u.id = uid.userid
    where u.username like 'prof%' 
        and ((DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(u.lastaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) > 6)
        -- filtro para las jefaturas
        and c.id in (
            SELECT id 
            FROM {course}
            where category in (
                select id 
                from {course_categories} 
                where path like (
                SELECT concat('/',data,'/%')  
                FROM {user_info_data}
                where fieldid = 1 and userid = ?
                )
            )
        )
        -- fin de filtro para las jefaturas
        and uid.fieldid = 4
    order by u.lastname, u.firstname
    ", array($USER->id));

    // Mostrar los JE - Prof que hace 7 días o mas que no se conecta a Moodle
    echo "<a name='j5'></a>";
    echo "<h2>JE - Prof que hace 7 días o mas que no se conecta a Moodle <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th>Nombre</th><th class='th-sm'>Email plataforma</th><th class='th-sm'>Email SIGAD</th><th>Ciclo</th><th>Centro</th><th>Último acceso</th><th>Hoy</th><th>Días entre</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->id}' target='_blank'>{$s->firstname} {$s->lastname}</a>";
        echo     " <a href='{$CFG->wwwroot}/message/index.php?id={$s->id}' target='_blank'><svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='currentColor' class='bi bi-chat-left-dots' viewBox='0 0 16 16'>
        <path d='M14 1a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H4.414A2 2 0 0 0 3 11.586l-2 2V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12.793a.5.5 0 0 0 .854.353l2.853-2.853A1 1 0 0 1 4.414 12H14a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z'/>
        <path d='M5 6a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0z'/> (mensaje)</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->email}</td>";
        echo   "<td style='text-align:right;'>{$s->data}</td>";
        echo   "<td>{$s->ciclo}</td>";
        echo   "<td>{$s->centro}</td>";
        echo   "<td style='text-align:right;'>{$s->ult_acceso}</td>";
        echo   "<td style='text-align:right;'>{$s->hoy}</td>";
        echo   "<td style='text-align:right;'>{$s->dias_entre_ult_acceso_y_hoy}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

    /***********************************************/
    // JE - Profesores que hace 7 dias o mas no acceden a un curso
    /***********************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        RAND(),
        c.id cid,
        c.fullname as curso,
        cc.name as ciclo,
        (select ccc.name from {course_categories} as ccc where ccc.id = SUBSTRING_INDEX(SUBSTRING(cc.path, 2), '/', 1  ) ) as centro,
        u.id uid,
        u.lastname,
        u.firstname,
        DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%d-%m-%Y %H:%i') as ult_acceso,
        DATE_FORMAT(now(), '%d-%m-%Y %H:%i') as hoy,
        DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1) as dias_desde_ult_acceso_al_curso
        , u.email
        , uid.data
    FROM {user_lastaccess} la
        join {user} as u on u.id = la.userid
        join {course} as c on c.id = la.courseid
        join {course_categories} as cc on c.category = cc.id
        join {user_info_data} uid on u.id = uid.userid
    where u.username like 'prof%' 
        and (DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) > 6
        and c.id not in (2, 3, 4, 368)
        and c.fullname not in ('Formación en centros de trabajo','Coordinación - Tutoría')
        -- filtro para las jefaturas
        and c.id in (
            SELECT id 
            FROM {course}
            where category in (
                select id 
                from {course_categories} 
                where path like (
                SELECT concat('/',data,'/%')  
                FROM {user_info_data} 
                where fieldid = 1 and userid = ?
                )
            )
        )
        -- fin de filtro para las jefaturas
        and uid.fieldid = 4
    order by u.lastname, u.firstname, c.fullname
    ", array($USER->id));

    // Mostrar JE - Profesores que hace 7 dias o mas no acceden a un curso
    echo "<a name='j6'></a>";
    echo "<h2>JE - Profesores que hace 7 dias o mas no acceden a un curso <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th>Nombre</th><th class='th-sm'>Email plataforma</th><th class='th-sm'>Email SIGAD</th><th>Curso</th><th>Ciclo</th><th>Centro</th><th>Ult. acceso</th><th>Hoy</th><th>Días entre</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->uid}' target='_blank'>{$s->firstname} {$s->lastname}</a>";
        echo     " <a href='{$CFG->wwwroot}/message/index.php?id={$s->uid}' target='_blank'><svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='currentColor' class='bi bi-chat-left-dots' viewBox='0 0 16 16'>
        <path d='M14 1a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H4.414A2 2 0 0 0 3 11.586l-2 2V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12.793a.5.5 0 0 0 .854.353l2.853-2.853A1 1 0 0 1 4.414 12H14a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z'/>
        <path d='M5 6a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0zm4 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0z'/> (mensaje)</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->email}</td>";
        echo   "<td style='text-align:right;'>{$s->data}</td>";
        echo   "<td>{$s->curso}</td>";
        echo   "<td>{$s->ciclo}</td>";
        echo   "<td>{$s->centro}</td>";
        echo   "<td style='text-align:right;'>{$s->ult_acceso}</td>";
        echo   "<td style='text-align:right;'>{$s->hoy}</td>";
        echo   "<td style='text-align:right;'>{$s->dias_desde_ult_acceso_al_curso}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

    /***********************************************/
    // JE - Videoconferencias
    /***********************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        rand()
        ,( select cc.name from www_fpvirtualaragon_es.mdl_course_categories cc where cc.id = c.category ) ciclo
        , c.id idcourse
        , c.fullname modulo
        , g.id id_sala
        , g.name nombre_sala
        , count(gr.id) grabaciones
   FROM {googlemeet} g
        inner join {googlemeet_recordings} gr on g.id = gr.googlemeetid
        inner join {course} c on g.course = c.id
        -- filtro para las jefaturas
        and c.id in (
            SELECT id 
            FROM {course}
            where category in (
                select id 
                from {course_categories} 
                where path like (
                SELECT concat('/',data,'/%')  
                FROM {user_info_data} 
                where fieldid = 1 and userid = ?
                )
            )
        )
        -- fin de filtro para las jefaturas
    group by c.shortname, g.name
    order by 2,3,5;
    ", array($USER->id));

    // Mostrar JE - Sesiones de videoconferencia
    echo "<a name='j7'></a>";
    echo "<h2>JE - Sesiones de videoconferencia <a href='#arriba'>[Subir]</a></h2>";
    echo "<p>Los cursos que no tienen sala de videoconferencia creada NO se muestran en el listado</p>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th class='th-sm'>Ciclo</th><th class='th-sm'>Curso</th><th class='th-sm'>Nombre sala</th><th>Sesiones</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo   "<td>{$s->ciclo}</td>";
        echo   "<td>";
        echo      "<a href='{$CFG->wwwroot}/course/view.php?id={$s->idcourse}' target='_blank'>{$s->modulo}</a>";
        echo   "</td>";
        echo   "<td>";
        echo      "{$s->nombre_sala}";
        echo   "</td>";
        echo   "<td>{$s->grabaciones}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";
}
echo '</div>';//container
echo '<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-C6RzsynM9kWDrMNeT87bh95OGNyZPhcTNXj1NW7RuBCsyN/o0jlpcV8Qyq46cDfL" crossorigin="anonymous"></script>';
echo '</body>';
echo '</html>';