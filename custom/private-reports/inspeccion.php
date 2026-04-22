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
echo '<title>Informes inspección</title>';
echo '<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-T3c6CoIi6uLrA9TneNEoa7RxnatzjcDSCmG1MXxSR1GAsXEV/Dwwykc2MPK8M2HN" crossorigin="anonymous">';
echo '</head>';
echo '<body>';
echo "<a name='arriba'></a>";
echo '<div class="container">';
echo "<h1>Informes inspección</h1>";


// Comprobar si el usuario es de inspección
$resultado = $DB->get_field_sql("
    select username
    from {user}
    where username = 'profinspector'
        and id = ?
    ", 
    array($USER->id));

if ($resultado == false ) {
    echo "<div class=\"alert alert-danger\" role=\"alert\">Solo el usuario Inspector tiene permisos para ver esta página.</div>";
    die();

}

echo "<p>Los informes de conexión del profesorado se muestran sin necesidad de elegir ningún curso.</p>";
echo "<p>El informe de días que se tarda en corregir una tarea requieren que se elija con antelación el curso que se quiere consultar.</p>";

// Obtener listado de cursos
$courses = $DB->get_records_sql("
    select 
        rand(),
        (select name from www_adistanciafparagon_es.mdl_course_categories cc2 where cc2.id = cc.parent ) centro
        , concat('(', description, ') ', name) ciclo, 
            c.fullname modulo,
            c.id id
    FROM www_adistanciafparagon_es.mdl_course_categories cc
        join www_adistanciafparagon_es.mdl_course c on c.category = cc.id
    where parent != 0
    order by 2, description, name
    ");

if (empty($courses)) {
    echo "No hay cursos en la base de datos";
    die();
}

// Si se ha enviado el formulario, obtener el curso
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $courseid = required_param('courseid', PARAM_INT);
    //$course = $DB->get_record('course', array('id' => $courseid), '*', MUST_EXIST);
}

// Formulario con la lista de cursos 
echo "<form method='post' action='inspeccion.php' >";
echo "<select name='courseid'>";
foreach ($courses as $c) {
    $selected = ($c->id == $courseid) ? 'selected' : '';
    echo "<option value='$c->id' $selected>$c->centro - $c->ciclo - $c->modulo</option>";
}
echo "</select>";
echo "<input type='submit' value='Buscar'>";
echo "</form>";
echo "<hr/>";

echo "<a href='#j1'>Profesores que hace 7 dias o mas no acceden a un curso</a><br/>";
echo "<a href='#j2'>Profesorado que hace 7 días o mas que no se conecta a Moodle</a><br/>";
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    echo "<a href='#j3'>Días que se tarda en corregir una tarea de estudiante</a><br/>";
}
    echo "<hr/>";
    /***********************************************/
    // Profesores que hace 7 dias o mas no acceden a un curso
    /***********************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        c.id cid,
        c.fullname,
        u.id uid,
        u.lastname,
        u.firstname,
        DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%d-%m-%Y %H:%i') as ult_acceso, 
        DATE_FORMAT(now(), '%d-%m-%Y %H:%i') as hoy,
        DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1) as dias_desde_ult_acceso_al_curso
    FROM {user_lastaccess} la
    join {user} as u on u.id = la.userid
    join {course} as c on c.id = la.courseid
    where u.username like 'prof%' 
        and u.username not like 'prof_je_%'
        and (DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(la.timeaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) > 6
        and c.id not in (2, 3, 4, 492, 491, 490, 406, 405, 404, 403, 402, 401)
        and c.fullname not in ('Formación en centros de trabajo','Coordinación - Tutoría')
    order by timeaccess
    ");
    
    // Mostrar los Profesores que hace 7 dias o mas no acceden a un curso
    echo "<a name='j1'></a>";
    echo "<h2>Profesores que hace 7 dias o mas no acceden a un curso <a href='#arriba'>[Subir]</a></h2>";
    echo "<p>El listado incluye profesores/as sin permiso de edición que han sido matriculados/as en el curso por el docente titular.</p>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th class='th-sm'>Docente</th><th class='th-sm'>Curso</th><th class='th-sm'>Ult. acceso</th><th>Hoy</th><th>Días entre</th></tr>";
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
        echo   "<td>";
        echo       "<a href='{$CFG->wwwroot}/course/view.php?id={$s->cid}' target='_blank'>{$s->fullname}</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->ult_acceso}</td>";
        echo   "<td style='text-align:right;'>{$s->hoy}</td>";
        echo   "<td style='text-align:right;'>{$s->dias_desde_ult_acceso_al_curso}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

    /****************************************************************************/
    // Obtener los Profesorado que hace 7 días o mas que no se conecta a Moodle
    /****************************************************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT 
        id,
        lastname,
        firstname,
        DATE_FORMAT(FROM_UNIXTIME(lastaccess), '%d-%m-%Y %H:%i') as ult_acceso , 
        DATE_FORMAT(now(), '%d-%m-%Y %H:%i') as hoy, 
        DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(lastaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1) as dias_entre_ult_acceso_y_hoy
    FROM {user}
    where username like 'prof%'
        and username not like 'prof_je_%'
        and ((DATEDIFF(DATE_FORMAT(FROM_UNIXTIME(lastaccess), '%Y-%m-%d %H:%i'), curdate() ) * (-1)) > 6)
    order by lastaccess
    ");

    // Mostrar los Profesorado que hace 7 días o mas que no se conecta a Moodle
    echo "<a name='j2'></a>";
    echo "<h2>Profesorado que hace 7 días o mas que no se conecta a Moodle <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th>Docente</th><th>Ult. acceso</th><th>Hoy</th><th>Días entre</th></tr>";
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
        echo   "<td style='text-align:right;'>{$s->ult_acceso}</td>";
        echo   "<td style='text-align:right;'>{$s->hoy}</td>";
        echo   "<td style='text-align:right;'>{$s->dias_entre_ult_acceso_y_hoy}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    /********************************************************************************/
    // Obtener los Días que se tarda en corregir una tarea de estudiante
    /********************************************************************************/
    $estudiantes = $DB->get_records_sql("
    SELECT
        rand() 
        , c.id cid
        , c.fullname as curso
        , cc.name as ciclo
        , (select ccc.name from {course_categories} as ccc where ccc.id = SUBSTRING_INDEX(SUBSTRING(cc.path, 2), '/', 1  ) ) as centro
        , tareas.name as tarea
        , u.firstname as nombre_de_quien_entrega
        , u.lastname as apellido_de_quien_entrega
        , entregas.status 
        , DATE_FORMAT(FROM_UNIXTIME(entregas.timecreated), '%d-%m-%Y %H:%i') primera_entrega_el
        , DATE_FORMAT(FROM_UNIXTIME(entregas.timemodified), '%d-%m-%Y %H:%i') ultima_correccion_el
        , ROUND((entregas.timemodified - entregas.timecreated)/60/60/24) as dias_entre_primera_entrega_y_ultima_correccion
        , (
                select count(*) 
                from {grade_grades_history}
                where userid = u.id and source = 'mod/assign' and loggeduser <> userid and itemid in  (
                    SELECT id 
                    FROM {grade_items} 
                    where iteminstance = tareas.id and courseid = c.id )
        ) num_correcciones
    FROM {assign} as tareas
        join {assign_submission} as entregas on tareas.id = entregas.assignment
        join {user} as u on u.id = entregas.userid
        join {course} as c on c.id = tareas.course 
        join {course_categories} as cc on c.category = cc.id
    where course = ?
    order by tarea, dias_entre_primera_entrega_y_ultima_correccion desc
    ", array($courseid));

    // Mostrar los Días que se tarda en corregir una tarea de estudianteo
    echo "<a name='j3'></a>";
    echo "<h2>Días que se tarda en corregir una tarea de estudianteo <a href='#arriba'>[Subir]</a></h2>";
    echo "<table class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr>";
    echo     "<th>Curso</th><th>Tarea</th><th>Estudiante</th>";
    echo     "<th>Status</th><th>Primera entrega</th><th>Última corrección</th><th>Días entre</th><th>Num. Correcciones</th>";
    echo "</tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo "  <td>";
        echo       "<a href='{$CFG->wwwroot}/course/view.php?id={$s->cid}' target='_blank'>{$s->curso} ($s->ciclo - $s->centro)</a>";
        echo "  </td>";
        echo "  <td>".$s->tarea."</td>";
        echo "  <td>{$s->nombre_de_quien_entrega} {$s->apellido_de_quien_entrega}</td>";
        echo "  <td>{$s->status}</td>";
        echo   "<td style='text-align:right;'>{$s->primera_entrega_el}</td>";
        echo   "<td style='text-align:right;'>{$s->ultima_correccion_el}</td>";
        echo   "<td style='text-align:right;'>{$s->dias_entre_primera_entrega_y_ultima_correccion}</td>";
        echo   "<td style='text-align:right;'>{$s->num_correcciones}</td>";
        echo "</tr>";
    }
    echo "</tbody>";
    echo "</table>";
}

echo '</div>';//container
echo '<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-C6RzsynM9kWDrMNeT87bh95OGNyZPhcTNXj1NW7RuBCsyN/o0jlpcV8Qyq46cDfL" crossorigin="anonymous"></script>';
echo '</body>';
echo '</html>';