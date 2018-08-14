-- COMP9311 18s1 Project 1
--
-- MyMyUNSW Solution Template


-- Q1: 
create or replace view Q1(unswid, name)
as
select unswid,name from people where id IN (select t1.student from course_enrolments t1,students t2 where t1.student=t2.id and t1.mark >= 85 and t2.stype='intl' group by t1.student having count(t1.student)>20)
;


-- Q2: 
create or replace view Q2(unswid, name)
as
select t1.unswid,t1.longname from rooms t1,buildings t2 where t1.building=t2.id and t2.name='Computer Science Building' and t1.capacity >=20 and t1.rtype IN (select id from room_types where description='Meeting Room')
;




-- Q3: 
create or replace view Q3(unswid, name)
as
select unswid,name from people where id in(select staff from course_staff where course IN(select course from course_enrolments where student=(select id from people where name ='Stefan Bilek')))
;



-- Q4:
create or replace view Q4(unswid, name) as
Select People.unswid, People.name
From People
inner join Students on Students.id = People.id
Where Students.id IN
    (Select student from Course_enrolments
      where Course_enrolments.course IN
            (Select ID from Courses
              where Courses.subject IN
                    (Select ID from Subjects
                      where code = 'COMP3331'

                    )
             )

      Except Select student from Course_enrolments
          where Course_enrolments.course IN
                (Select ID from Courses
                  where Courses.subject IN
                        (Select ID from Subjects
                            where code = 'COMP3231'

                          )
                   )

        )
        ;


-- Q5: 
create or replace view Q5a(num)
as
select count(distinct(t1.id)) from program_enrolments t1,students t2,stream_enrolments t3,streams t4 where 

t1.student=t2.id and t2.stype='local' and t1.id=t3.partof and t4.name='Chemistry' and t3.stream=t4.id  and
t1.semester=(select id from semesters where name='Sem1 2011')
;

-- Q5: 
create or replace view Q5b(num)
as
select count((t1.student)) from program_enrolments t1,students t2,programs t3,orgunits t4 where t1.student=t2.id and 
t2.stype='intl' and t3.offeredby=t4.id and t1.program=t3.id and t4.name='Computer Science and Engineering, School of'
and t1.semester=(select id from semesters where name='Sem1 2011')
;


-- Q6:
create or replace function
	Q6(text) returns text
as
$$
select code||' '||name||' '||uoc
	from subjects
	where subjects.code = $1
$$ language sql;



-- Q7:
create or replace view internationalstudents
as
select t3.code,t3.name,count(t1.student) as ci,t3.id from program_enrolments t1,students t2,programs t3 where t1.student=t2.id and t1.program=t3.id and t2.stype='intl' group by t3.id
;

create or replace view totalstudents
as
select ta3.code,ta3.name,count(ta1.student) as ct,ta3.id from program_enrolments ta1,students ta2,programs ta3 where ta1.student=ta2.id and ta1.program=ta3.id  group by ta3.id
; 
create or replace view Q7(code, name)
as
select y1.code,y1.name from internationalstudents y1,totalstudents y2 where  y1.id=y2.id and (y1.ci::decimal / y2.ct) > 0.50
;



-- Q8:
create or replace view courseaverage
as
select course,AVG(mark) as average from course_enrolments where course IN( select course from course_enrolments group by course having count(mark>=0) >=15) group by course;
;


create or replace view coursedetails
as
select subject,semester from courses where id=(select course from courseaverage where average=(select MAX(average) from courseaverage))
;

create or replace view Q8(code, name, semester)
as
select y1.code,y1.name,y2.name from subjects y1,semesters y2,coursedetails y3 where y1.id=y3.subject and y2.id=y3.semester

;



-- Q9:
create or replace view findschools
as
select z1.id as sid from orgunits z1,orgunit_types z2 where z1.utype=z2.id and z2.name='School'
;

create or replace view findstaffs
as
select t1.staff,t1.orgunit,t1.starting from affiliations t1,findschools t2  where t1.isprimary='t' and t1.ending IS  NULL and t1.orgunit=t2.sid and t1.role=(select id from staff_roles where name='Head of School')
;

create or replace view findnumsubjects
as
select t3.staff,count(distinct(t4.code)) as numsub  from courses t1,course_staff t2,findstaffs t3,subjects t4 where t2.staff=t3.staff and t1.id=t2.course and t1.subject=t4.id group by t3.staff having count(distinct(t4.code))>0  
;

create or replace view Q9(name, school, email, starting, num_subjects)
as
select t1.name,t2.longname,t1.email,t3.starting,t4.numsub from people t1,orgunits t2,findstaffs t3,findnumsubjects t4 where t1.id=t3.staff and t2.id=t3.orgunit and t1.id=t4.staff 
;



-- Q10:
create or replace view subjectids1s2
as
SELECT Subjects.id,Subjects.code,Subjects.name 
From Semesters,Subjects,Courses 
WHERE SUBSTR(Subjects.code,1,6)='COMP93' AND Subjects.id=Courses.subject 
AND Courses.semester=Semesters.id 
GROUP BY Subjects.id 
HAVING COUNT(Courses.id)=24 
;





create or replace function Q10_1(integer,text,integer) returns bigint as
$$SELECT COUNT(Course_enrolments.student) as bigint
FROM Semesters,Courses,Course_enrolments,Subjects 
WHERE Semesters.year=$1 AND Semesters.term=$2 AND Courses.semester=Semesters.id 
AND Course_enrolments.course=Courses.id AND Course_enrolments.mark>=85 
AND Courses.subject=Subjects.id AND Subjects.id=$3 
$$ language sql;

--...Q10_2 is a function about the amount of students who actually received a mark in DB
create or replace function Q10_2(integer,text,integer) returns bigint as
$$SELECT COUNT(Course_enrolments.student) as bigint
FROM Semesters,Courses,Course_enrolments,Subjects  
WHERE Semesters.year=$1 AND Semesters.term=$2 AND Courses.semester=Semesters.id 
AND Course_enrolments.course=Courses.id AND Course_enrolments.mark>=0 
AND Courses.subject=Subjects.id AND Subjects.id=$3 
$$ language sql;

--...Q9 is a view about the pass rate of S1 and S2 in different year
create or replace view Q10(code,name,year, s1_pass_rate, s2_pass_rate)
as
SELECT subjectids1s2.code,subjectids1s2.name,SUBSTR(CAST(Semesters.year AS VARCHAR(5)),3,2),CAST(1.0*Q10_1(Semesters.year,'S1',subjectids1s2.id)/Q10_2(Semesters.year,'S1',subjectids1s2.id) AS numeric(4,2)),
CAST(1.0*Q10_1(Semesters.year,'S2',subjectids1s2.id)/Q10_2(Semesters.year,'S2',subjectids1s2.id) AS numeric(4,2)) 
FROM Semesters,subjectids1s2
WHERE Q10_2(Semesters.year,'S1',subjectids1s2.id)!=0 AND Q10_2(Semesters.year,'S2',subjectids1s2.id)!=0
GROUP BY subjectids1s2.code,subjectids1s2.name,Semesters.year,subjectids1s2.id 
ORDER BY subjectids1s2.code,subjectids1s2.name,Semesters.year,subjectids1s2.id 
;
