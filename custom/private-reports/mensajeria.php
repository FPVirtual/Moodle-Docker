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
echo "<h1>Consulta de mensajería</h1>";


// Obtener los usuarios con quienes hemos intercambiado mensajes
$users = $DB->get_records_sql("
    SELECT distinct lmmu1.userid, u.firstname, u.lastname
    FROM {local_mail_messages}  lmm -- Mensajes
	    join {local_mail_message_users} lmmu1 on lmmu1.messageid = lmm.id -- Qué mensaje tiene qué usuario
        join {local_mail_message_users} lmmu2 on lmmu2.messageid = lmm.id -- Qué mensaje tiene qué usuario    
        join {user} u on u.id = lmmu1.userid
    where 
	    -- Me quedo con los mensajes que ha enviado o recibido
	    lmmu1.userid = ? or lmmu2.userid = ? 
    order by u.lastname, u.firstname", 
    array($USER->id, $USER->id));

if (empty($users)) {
    echo "El usuario " . $USER->id . " no ha intercambiado mensajes con nadie";
    die();
}

// Si se ha enviado el formulario, obtener el curso
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $useridconsultado = required_param('useridconsultado', PARAM_INT);
    //$course = $DB->get_record('course', array('id' => $courseid), '*', MUST_EXIST);
}

// Formulario con la lista de personas con quien hemos interambiado mensajes
echo "<form method='post' action='mensajeria.php' >";
echo "<select name='useridconsultado'>";
foreach ($users as $u) {
    $selected = ($u->userid == $useridconsultado) ? 'selected' : '';
    echo "<option value='$u->userid' $selected>$u->firstname $u->lastname </option>";
}
echo "</select>";
echo "<input type='submit' value='Buscar'>";
echo "</form>";
echo "<hr/>";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    /*

    echo "<a href='#estudiantes-activos-nunca-accedido'>Estudiantes activos que nunca han accedido al curso</a><br/>";
    echo "<a href='#estudiantes-mas-10'>Estudiantes que llevan más de 10 días sin conectarse al curso</a><br/>";
    echo "<a href='#estudiantes-entre-7-10'>Estudiantes que llevan entre 7 y 10 días sin conectarse al curso</a><br/>";
    echo "<a href='#estudiantes-matriculados'>Listado de matriculación</a><br/>";
    echo "<hr/>";*/
    /***********************************************/
    // Estudiantes activos que nunca han accedido al curso
    /***********************************************/

/*
SELECT m.*, mu1.userid as sender_id, mu2.userid as receiver_id
FROM mdl_local_mail_messages m
    JOIN mdl_local_mail_message_users mu1 ON m.id = mu1.messageid AND mu1.role = 1
    JOIN mdl_local_mail_message_users mu2 ON m.id = mu2.messageid AND mu2.role IN (2, 3, 4)
WHERE 
    (mu1.userid = YOUR_USER_ID AND mu2.userid = TARGET_USER_ID) -- 5369 y 3745
    OR 
    (mu1.userid = TARGET_USER_ID AND mu2.userid = YOUR_USER_ID)
ORDER BY m.time DESC;
*/

    $estudiantes = $DB->get_records_sql("
    SELECT 
        RAND()
        , lmm.id
        , c.fullname
        , c.id
        , lmm.subject
        , lmm.content
        , lmm.normalizedcontent
        , DATE_FORMAT(FROM_UNIXTIME(lmm.time), '%d-%m-%Y %H:%i') fecha_hora
        , lmmu1.userid as userid1
        , (select concat(u.firstname, ' ', u.lastname) from {user} u where u.id = lmmu1.userid) as username1
        , lmmu2.userid as userid2
        , (select concat(u.firstname, ' ' ,u.lastname) from {user} u where u.id = lmmu2.userid) as username2

    FROM {local_mail_messages}  lmm -- Mensajes
        join {local_mail_message_users} lmmu1 on lmmu1.messageid = lmm.id and lmmu1.role = 1 -- Qué mensaje tiene qué usuario
        join {local_mail_message_users} lmmu2 on lmmu2.messageid = lmm.id and lmmu2.role in (2, 3, 4)-- Qué mensaje tiene qué usuario
        join {course} c on lmm.courseid = c.id

    where 
        -- Me quedo con los mensajes cuyo id tienen ambos
        (lmmu1.userid = ? and lmmu2.userid = ?) or (lmmu1.userid = ? and lmmu2.userid = ?)
        
    order by lmm.time desc
    ",array($USER->id, $useridconsultado, $useridconsultado, $USER->id));

    // Mostrar los mensajes intercambiados con la persona seleccionada
    echo "<a name='estudiantes-activos-nunca-accedido'></a>";
    echo "<h2>Mensajes de correo <a href='#arriba'>[Subir]</a></h2>";
    echo "<table id='dtBasicExample' class='table table-striped table-bordered table-sm'>";
    echo "<thead>";
    echo "<tr><th class='th-sm'>Curso</th><th class='th-sm'>From</th><th class='th-sm'>To, cc, bcc</th><th class='th-sm'>Cuando</th><th class='th-sm'>Asunto</th><th class='th-sm'>Contenido</th></tr>";
    echo "</thead>";
    echo "<tbody>";
    foreach ($estudiantes as $s) {
        echo "<tr>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/course/view.php?id={$s->id}' target='_blank'>{$s->fullname}</a>";
        echo   "</td>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->userid1}' target='_blank'>{$s->username1}</a>";
        echo   "</td>";
        echo   "<td>";
        echo     "<a href='{$CFG->wwwroot}/user/view.php?id={$s->userid2}' target='_blank'>{$s->username2}</a>";
        echo   "</td>";
        echo   "<td style='text-align:right;'>{$s->fecha_hora}</td>";
        echo   "<td style='text-align:right;'>{$s->subject}</td>";
        echo   "<td style='text-align:right;'>{$s->content}</td>";
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