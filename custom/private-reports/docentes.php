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
echo '<title>Informes profesorado</title>';
echo '<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-T3c6CoIi6uLrA9TneNEoa7RxnatzjcDSCmG1MXxSR1GAsXEV/Dwwykc2MPK8M2HN" crossorigin="anonymous">';
echo '</head>';
echo '<body>';
echo '<main>';
echo "<a name='arriba'></a>";
echo '<div class="container">';
echo "<h1>Informes para profesorado</h1>";


// Obtener los cursos en los que el usuario tiene el rol de profesor con una consulta SQL sin usar funciones de Moodle
$courses = $DB->get_records_sql("
    SELECT c.id, c.fullname
    FROM {course} c
    JOIN {context} ctx ON ctx.instanceid = c.id
    JOIN {role_assignments} ra ON ra.contextid = ctx.id
    JOIN {role} r ON r.id = ra.roleid
    WHERE ra.userid = ? AND r.shortname in (?, ?)
    GROUP BY c.id, c.fullname
    ORDER BY c.fullname", 
    array($USER->id, "editingteacher", "teacher"));
if (empty($courses)) {
    echo "El usuario " . $USER->id . " no tiene cursos asignados";
    die();
}

// Si se ha enviado el formulario, obtener el curso
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $courseid = required_param('courseid', PARAM_INT);
    $course = $DB->get_record('course', array('id' => $courseid), '*', MUST_EXIST);
}

// Formulario con la lista de cursos en que el usuario tiene el rol de profesor
echo "<form method='post' action='docentes.php' >";
echo "<select name='courseid'>";
foreach ($courses as $c) {
    $selected = ($c->id == $courseid) ? 'selected' : '';
    echo "<option value='$c->id' $selected>$c->fullname</option>";
}
echo "</select>";
echo "<input type='submit' value='Buscar'>";
echo "</form>";
echo "<hr/>";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {


    echo "<a href='#estudiantes-activos-nunca-accedido'>Estudiantes activos que nunca han accedido al curso</a><br/>";
    echo "<a href='#estudiantes-mas-10'>Estudiantes que llevan más de 10 días sin conectarse al curso</a><br/>";
    echo "<a href='#estudiantes-entre-7-10'>Estudiantes que llevan entre 7 y 10 días sin conectarse al curso</a><br/>";
    echo "<a href='#estudiantes-matriculados'>Listado de matriculación</a><br/>";
    echo "<hr/>";
    /***********************************************/
    // Estudiantes activos que nunca han accedido al curso
    /***********************************************/
    $estudiantes = $DB->get_records_sql("
    select 
        u.id,
        u.lastname,
        u.firstname,
        DATE_FORMAT(FROM_UNIXTIME(ue.timecreated), '%Y-%m-%d %H:%i') matriculado_el
        , u.email
        , uid.data
    from {user_enrolments} ue
        join {user} as u on u.id = ue.userid
        join {user_info_data} uid on u.id = uid.userid
    where ue.status = 0
        and ue.enrolid in 
            (select e.id
            from {enrol} e 
            where e.courseid = ?
            )
        and ue.userid not in (select userid from {user_lastaccess} where courseid = ?)
        and uid.fieldid = 4
    ", array($courseid, $courseid));

    // Mostrar los Estudiantes activos que nunca han accedido al curso
    echo "<a name='estudiantes-activos-nunca-accedido'></a>";
    echo "<h2>Estudiantes activos que nunca han accedido al curso <a href='#arriba'>[Subir]</a></h2>";
    echo "<table id='dtBasicExample' class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th class='th-sm'>Nombre</th><th class='th-sm'>Email plataforma</th><th class='th-sm'>Email SIGAD</th><th class='th-sm'>Matriculado el</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->id}' target='_blank'>{$s->firstname} {$s->lastname}</a>";
        echo     " <a href='{$CFG->wwwroot}/message/index.php?id={$s->id}' target='_blank'>(mensaje)</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->email}</td>";
        echo   "<td style='text-align:right;'>{$s->data}</td>";
        echo   "<td style='text-align:right;'>{$s->matriculado_el}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

    /****************************************************************************/
    // Obtener los estudiantes que llevan más de 10 días sin conectarse al curso
    /****************************************************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        u.id,
        u.lastname,
        u.firstname ,
        DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%d-%m-%Y %H:%i') as ult_acceso, 
        DATE_FORMAT(now(), '%d-%m-%Y %H:%i') as hoy,
        DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1) as dias_entre_ult_acceso_y_hoy
        , u.email
        , uid.data
    FROM {user_lastaccess} la
        join {user} as u on u.id = la.userid
        join {course} as c on c.id = la.courseid
        join {user_enrolments} as ue on ue.userid = u.id
        join {user_info_data} uid on u.id = uid.userid
    where u.username not like 'prof%' 
        and ((DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) > 10)
        and c.id  = ?
        and ue.enrolid in 
                        (select e.id
                        from {enrol} e 
                        where e.courseid = ?
                            )
        and ue.status = 0 -- activo: 0 suspendido: 1
        and uid.fieldid = 4
    order by timeaccess
    ", array($courseid, $courseid));

    // Mostrar los estudiantes que llevan más de 10 días sin conectarse al curso
    echo "<a name='estudiantes-mas-10'></a>";
    echo "<h2>Estudiantes que llevan más de 10 días sin conectarse al curso <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th>Nombre</th><th class='th-sm'>Email plataforma</th><th class='th-sm'>Email SIGAD</th><th>Último acceso</th><th>hoy</th><th>dias entre</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->id}' target='_blank'>{$s->firstname} {$s->lastname}</a>";
        echo     " <a href='{$CFG->wwwroot}/message/index.php?id={$s->id}' target='_blank'>(mensaje)</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->email}</td>";
        echo   "<td style='text-align:right;'>{$s->data}</td>";
        echo   "<td style='text-align:right;'>{$s->ult_acceso}</td>";
        echo   "<td style='text-align:right;'>{$s->hoy}</td>";
        echo   "<td style='text-align:right;'>{$s->dias_entre_ult_acceso_y_hoy}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

    /********************************************************************************/
    // Obtener los estudiantes que llevan entre 7 y 10 días sin conectarse al curso
    /********************************************************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        u.id,
        u.lastname,
        u.firstname,
        DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%d-%m-%Y %H:%i') as ult_acceso, 
        DATE_FORMAT(now(), '%d-%m-%Y %H:%i') as hoy,
        DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1) as dias_entre_ult_acceso_y_hoy
        , u.email
        , uid.data
    FROM {user_lastaccess} la
        join {user} as u on u.id = la.userid
        join {course} as c on c.id = la.courseid
        join {user_enrolments} as ue on ue.userid = u.id
        join {user_info_data} uid on u.id = uid.userid
    where u.username not like 'prof%' 
        and ((DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) > 4)
        and ((DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) < 10)
        and c.id  = ?
        and ue.enrolid in 
                        (select e.id
                        from {enrol} e 
                        where e.courseid = ?
                            )
        and ue.status = 0 -- activo: 0 suspendido: 1
        and uid.fieldid = 4
    order by timeaccess
    ", array($courseid, $courseid));

    // Mostrar los estudiantes que llevan entre 7 y 10 días sin conectarse al curso
    echo "<a name='estudiantes-entre-7-10'></a>";
    echo "<h2>Estudiantes que llevan entre 7 y 10 días sin conectarse al curso <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th>Nombre</th><th class='th-sm'>Email plataforma</th><th class='th-sm'>Email SIGAD</th><th>Último acceso</th><th>Hoy</th><th>Días entre</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->id}' target='_blank'>{$s->firstname} {$s->lastname}</a>";
        echo     " <a href='{$CFG->wwwroot}/message/index.php?id={$s->id}' target='_blank'>(mensaje)</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->email}</td>";
        echo   "<td style='text-align:right;'>{$s->data}</td>";
        echo   "<td style='text-align:right;'>{$s->ult_acceso}</td>";
        echo   "<td style='text-align:right;'>{$s->hoy}</td>";
        echo   "<td style='text-align:right;'>{$s->dias_entre_ult_acceso_y_hoy}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

    /***********************************************/
    // Listado de matriculación
    /***********************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        u.id    
        , u.firstname
        , u.lastname 
        , u.email
        , uid.data
        , DATE_FORMAT(FROM_UNIXTIME(ue.timecreated), '%d-%m-%Y %H:%i') matriculado_el
        , DATE_FORMAT(FROM_UNIXTIME(ue.timemodified), '%d-%m-%Y %H:%i') modificado_el
        , DATE_FORMAT(FROM_UNIXTIME(u.lastaccess), '%d-%m-%Y %H:%i') ultimo_acceso
    from {user_enrolments} as ue
        join {user} as u on u.id = ue.userid
        join {enrol} as e on e.id = ue.enrolid
        join {course} as c on c.id = e.courseid
        join {user_info_data} uid on u.id = uid.userid
    where e.courseid = ? 
        and ue.status = 0 -- activo: 0 suspendido: 1
        and uid.fieldid = 4
    ", array($courseid, $courseid));

    // Mostrar Listado de matriculación
    echo "<a name='estudiantes-matriculados'></a>";
    echo "<h2>Listado de matriculación <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th>Nombre</th><th>Correo</th><th>Correo SIGAD</th><th>Matriculado el</th><th>Modificado el</th><th>Último acceso</th></tr>";
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
        echo   "<td>";
        echo   "{$s->email}";
        echo   "</td>";
        echo   "<td>";
        echo   "{$s->data}";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->matriculado_el}</td>";
        $clase = "";
        if($s->matriculado_el != $s->modificado_el){
            $clase = 'class="table-warning"';
        }
        echo   "<td style='text-align:right;' {$clase} >{$s->modificado_el}</td>";
        echo   "<td>";
        echo   "{$s->ultimo_acceso}";
        echo   "</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

}
echo '</div>';//container
echo '</main>';
echo '<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-C6RzsynM9kWDrMNeT87bh95OGNyZPhcTNXj1NW7RuBCsyN/o0jlpcV8Qyq46cDfL" crossorigin="anonymous"></script>';
echo '<script>';
echo "$('#dtBasicExample').DataTable();";
echo "$('.dataTables_length').addClass('bs-select');";
echo '</script>';
echo '</body>';
echo '</html>';