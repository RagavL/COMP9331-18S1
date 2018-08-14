--Q1:

--Q1:
drop type if exists RoomRecord cascade;
create type RoomRecord as (valid_room_number integer, bigger_room_number integer);
create or replace function Q1(course_id integer)
    returns RoomRecord
as $$
--... SQL statements, possibly using other views/functions defined by you ...
 declare RRe RoomRecord;
  A integer; 
  B integer;
 begin
  
  if not exists(select * from courses where courses.id = $1) then
  raise exception 'INVALID COURSEID';
  end if;
  if exists(select * from courses where courses.id = $1) then
  select count(course_enrolments.student) into A from course_enrolments,courses
  where course_enrolments.course=courses.id
  and courses.id= $1;
  select count(*) into RRe.valid_room_number from rooms
  where rooms.capacity >= A;
  select count(course_enrolment_waitlist.student) into B from courses, course_enrolment_waitlist
  where course_enrolment_waitlist.course=courses.id
  and courses.id = $1;
  select count(*) into RRe.bigger_room_number from rooms
  where rooms.capacity >=(A+B);
  return RRe;
  end if;
 end;
$$ language plpgsql;




--Q2:
DROP AGGREGATE IF EXISTS median(numeric) CASCADE;
CREATE OR REPLACE FUNCTION array_median(numeric[])
RETURNS NUMERIC AS
$$
SELECT CASE
	WHEN array_upper(asorted, 1) = 0 THEN NULL 
	WHEN array_upper(asorted, 1) % 2 = 1 THEN asorted[CEILING(array_upper(asorted,1)/2.0)] 
	ELSE (asorted[CEILING(array_upper(asorted,1)) / 2.0] + asorted[CEILING(array_upper(asorted,1)) / 2.0 + 1]) / 2.0
	END
	FROM (SELECT ARRAY (SELECT ($1)[n] 
			FROM generate_series(1, array_upper($1, 1)) AS n
			WHERE ($1)[n] IS NOT NULL ORDER BY ($1)[n]
						) AS asorted
			) AS foo ;
$$
LANGUAGE 'sql' IMMUTABLE;

CREATE AGGREGATE median(NUMERIC)
(
  SFUNC=array_append,
  STYPE=NUMERIC[],
  FINALFUNC=array_median
);


create or replace view Q2_1
as
select course,count(student) as nstudents from course_enrolments where mark >=0  group by course;

create or replace view Q2_2
as 
select c.id,c.subject,c.semester,sem.year,sem.term,sem.name as semname,sub.code,sub.name,sub.uoc,nse.nstudents,cs.staff from 
courses c,course_staff cs,subjects sub,semesters sem,Q2_1 nse
where c.id=cs.course and c.subject=sub.id and c.semester=sem.id and nse.course=c.id and nse.nstudents >0;

create or replace view Q2_3
as
select c.id,avg(ce.mark),max(ce.mark),median(ce.mark) from courses c,course_enrolments ce,Q2_1 nse where c.id=ce.course and c.id=nse.course and ce.mark IS NOT NULL and 
nse.nstudents >0 group by c.id;


drop type if exists TeachingRecord cascade;
create type TeachingRecord as (cid integer, term char(4), code char(8), name text, uoc integer, average_mark integer, highest_mark integer, median_mark integer, totalEnrols integer);

create or replace function Q2(staff_id integer)
	returns setof TeachingRecord
as $$
begin
perform * from staff s,people p where s.id=p.id and s.id=$1;
if(not found) then
	raise exception 'INVALID STAFFID';
end if;
return query select t1.id,cast(substr(cast(t1.year as char(5)),3,2)||(lower(t1.term)) as char(4)),t1.code,cast(t1.name as text),t1.uoc,cast(t2.avg as integer),
cast(t2.max as integer),cast(t2.median as integer),cast(t1.nstudents as integer) from Q2_2 t1,Q2_3 t2 where t1.id=t2.id and staff=$1;
end;
$$ language plpgsql;


--Q3:
create or replace function Q3_org(org_id integer)
returns table(owner integer,member integer)
as $$
with recursive q as (select member,owner from orgunit_groups where member=$1
union all select m.member,m.owner from orgunit_groups m join q on q.member=m.owner)
select owner,member from q;
$$ language sql;

create or replace function Q3_org2(org_id integer)
returns table(owner integer,member integer,name mediumstring)
as $$
select Q3_org.owner,Q3_org.member,orgunits.name
from Q3_org($1),orgunits
where orgunits.id=Q3_org.member
$$ language sql;

create or replace function Q3_1(org_id integer,num_sub integer,min_score integer)
	returns table(unswid integer, student_name text)
as $$
select people.unswid,cast(people.name as text)
from Q3_org2($1),subjects,courses,course_enrolments,students,people
where  subjects.offeredby=Q3_org2.member and courses.subject=subjects.id 
and course_enrolments.student=students.id and course_enrolments.course=courses.id and people.id=students.id
group by people.unswid,people.name
having count(courses.id) > $2 and max(case when course_enrolments.mark >=$3 then 1 else 0 end)=1; 
$$ language sql;

create or replace function Q3_sub(org_id integer)
	returns table(unswid integer, student_name text, subject_id integer,subject_code char(8),cours_id integer, name mediumstring)
as $$
select people.unswid,cast(people.name as text),subjects.id,subjects.code, courses.id,Q3_org2.name
from Q3_org2($1),subjects,courses,course_enrolments,people,students
where  subjects.offeredby=Q3_org2.member and courses.subject=subjects.id 
and course_enrolments.student=students.id and course_enrolments.course=courses.id and people.id=students.id;
$$ language sql;


create or replace view Q3_sub(unswid,student_name,subject_id,subject_code,cours_id,org_name)
as
select people.unswid,cast(people.name as text),subjects.id,subjects.code, courses.id,orgunits.name
from orgunits,subjects,courses,course_enrolments,people,students
where  subjects.offeredby=orgunits.id and courses.subject=subjects.id 
and course_enrolments.student=students.id and course_enrolments.course=courses.id  
and people.id=students.id;

create or replace function Q3_sub(org_id integer)
	returns table(unswid integer, student_name text, subject_id integer,subject_code char(8),cours_id integer, name mediumstring)
as $$
select people.unswid,cast(people.name as text),subjects.id,subjects.code, courses.id,orgunits.name
from orgunits,subjects,courses,course_enrolments,people,students
where  subjects.offeredby=orgunits.id and courses.subject=subjects.id
and course_enrolments.student=students.id and course_enrolments.course=courses.id and people.id=students.id;
$$ language sql;


create or replace function Q3_2(org_id integer,num_sub integer,num_times integer)
	returns table(unswid integer, student_name text, subjects char(8),count_sub bigint)
as $$
select unswid,student_name,subject_code,count(subject_code)
from Q3_sub($1)
where  unswid in (select unswid from Q3_1($1,$2,$3))
group by unswid,student_name,subject_code;
$$ language sql;


create or replace function Q3_2(org_id integer,num_sub integer,num_times integer)
	returns table(unswid integer, student_name text, subjects char(8),count_sub bigint)
as $$
select qs.unswid,qs.student_name,qs.subject_code,count(subject_id)
from Q3_sub qs inner join (select * from Q3_1($1,$2,$3)) q31 on qs.unswid=q31.unswid
group by qs.unswid,qs.student_name,qs.subject_code,subject_id
$$ language sql;

create or replace function Q3_2(org_id integer,num_times integer)
	returns table(unswid integer, student_name text, subjects char(8), subject_name text ,count_cou integer, name mediumstring,semester_name text,mark integer)
as $$
select people.unswid,cast(people.name as text),subjects.code,subjects.name,courses.id, Q3_org2.name,semesters.name,course_enrolments.mark
from Q3_org2($1),subjects,courses,course_enrolments,students,people,semesters
where  subjects.offeredby=Q3_org2.member and courses.subject=subjects.id and courses.semester=semesters.id
and course_enrolments.student=students.id and course_enrolments.course=courses.id and people.id=students.id
group by people.unswid,people.name,subjects.code,Q3_org2.name,subjects.name,semesters.name,course_enrolments.mark,courses.id
$$ language sql;


create or replace function Q3_3(org_id integer,num_sub integer,min_score integer)
        returns table(unswid integer, student_name text,mark bigint,records text)
as $$
select * from (select Q3_1.unswid,Q3_1.student_name,rank () over( partition by Q3_1.unswid,Q3_1.student_name order by  Q3_2.mark desc NULLS LAST) as rank, cast(Q3_2.subjects || ', ' || Q3_2.subject_name || ', ' || Q3_2.semester_name || ', ' || Q3_2.name || ', ' || Q3_2.mark as text)  
from Q3_1($1,$2,$3),Q3_2($1,$2) 
where Q3_1.unswid=Q3_2.unswid
--)t where rank <=5;
order by Q3_1.unswid,Q3_2.mark desc NULLS LAST,Q3_2.count_cou
)t where rank <=5;
$$ language sql;




drop type if exists CourseRecord cascade;
create type CourseRecord as (unswid integer, student_name text, course_records text);

create or replace function Q3(org_id integer, num_courses integer, min_score integer)
  returns setof CourseRecord
as $$
begin


if not exists(select * from orgunits where orgunits.id=$1) then 
	raise exception 'INVALID ORGID';
end if;
return query select unswid,student_name, string_agg(records,chr(10))|| chr(10) from Q3_3($1,$2,$3) group by unswid,student_name;
end;
$$ language plpgsql;



