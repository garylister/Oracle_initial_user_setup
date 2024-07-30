-- comment this out for squirrel.  you'll also need to create the table and then run the rest of the script
SET SERVEROUTPUT ON;  

-- check for the created_users table and only try to create it if it doesn't exist
declare
v_table_count number;
begin
select count into v_table_count from (select count(*) as count from dba_tables where owner = 'ROOT' 
and table_name = 'CREATED_USERS');
if v_table_count = 0 then
execute immediate 'create table root.created_users ( name varchar2(20), password varchar2(200))';
DBMS_OUTPUT.PUT_LINE('creating created_users table');
else 
-- if the table exists do nothing
DBMS_OUTPUT.PUT_LINE('created_users table already exists');
end if;
end;
/

declare

-- variables for working with passwords
v_new_passwd varchar2(12);
v_encoded_password raw(200);
v_decoded_password varchar2(15);

-- create a collection to hold the list of users
type t_users is table of varchar2(20);

-- list of users/roles to create
v_users t_users := t_users ('SCHEMA1','SCHEMA2','SCHEMA3','SCHEMA4','SCHEMA5','SUPPORT','DEVELOPER','QA','QAFLYWAY');

-- variables for verifying if a user or tablespace exist
v_varchar_user varchar2(20);
v_tablespc_count number;
v_user_count number;

function gen_passwd
return varchar2
is 
v_password varchar2(12):= '' ;
v_rand_num number;
begin 
loop
-- pick a random number in the range for the usable characters
v_rand_num := round(dbms_random.value(33,122));
-- this omits the following characters " ' ( ) + , - . / : ;  < = > [ \ ] _ `
if v_rand_num not in (34,39,40,41,43,44,45,46,47,58,59,60,61,62,91,92,93,95,96) then
v_password := concat(v_password, chr(v_rand_num));
end if;
exit when length(v_password) = 12;
end loop;
return v_password;
end;

-- main part of the script
begin

-- loop through the list of users
for i in 1..v_users.count loop

-- set the list item as a varchar2 to use in the functions
v_varchar_user := v_users(i);
DBMS_OUTPUT.PUT_LINE(v_varchar_user);

-- check if the tablespace exists
select num into v_tablespc_count from (select count(*) as num from dba_tablespaces where tablespace_name = v_varchar_user||'_TS' );
-- if it doesn't exist create the tablespace
if v_tablespc_count  = 0 then
execute immediate 'create tablespace '||v_varchar_user||'_TS datafile size 1000M autoextend on next 100M';
DBMS_OUTPUT.PUT_LINE('create tablespace '||v_varchar_user||'_TS datafile size 1000M autoextend on next 100M');

else 
-- if the tablespace already exists, do nothing
DBMS_OUTPUT.PUT_LINE('tablespace alreay exists');
end if;

-- check if the user exists
select num into v_user_count from (select count(*) as num from dba_users where username = v_varchar_user );

-- if not start the creatation process
if v_user_count = 0 then
-- create a password for the user
v_new_passwd := gen_passwd();
-- encode the password so when we save it in a table it won't be plaintext
v_encoded_password := sys.utl_encode.base64_encode(sys.utl_raw.cast_to_raw(v_new_passwd));

-- decode the password to be able to use it.
v_decoded_password := sys.utl_raw.cast_to_varchar2((sys.utl_encode.base64_decode(v_encoded_password)));
-- uncomment this to have the password printed in the console
-- DBMS_OUTPUT.PUT_LINE(v_decoded_password);

-- log the user and encoded password to the database.  this way the script can be run from the maintenance server
-- and the credentials can still be easily obtained
execute immediate 'insert into root.created_users values ('''||v_varchar_user||''', '''||v_encoded_password||''')';
DBMS_OUTPUT.PUT_LINE('insert into root.created_users values ('''||v_varchar_user||''', '''||v_encoded_password||''')');
 commit;

-- create the actual user and grant basic login privileges
execute immediate 'create user '||v_varchar_user||' identified by "'||v_new_passwd||
'" default tablespace '||v_varchar_user||'_TS quota unlimited on '||v_varchar_user||'_TS temporary tablespace temp';
DBMS_OUTPUT.PUT_LINE('create user '||v_varchar_user||' identified by "'||v_new_passwd||
'" default tablespace '||v_varchar_user||'_TS quota unlimited on '||v_varchar_user||'_TS temporary tablespace temp');
execute immediate 'grant connect, resource to '||v_varchar_user;
DBMS_OUTPUT.PUT_LINE('grant connect, resource to '||v_varchar_user);


-- if the user is a service user, grant the remainder of the needed privileges.  non-service users have privileges granted
-- through roles that are created in a separate script
if v_varchar_user in ('SCHEMA1','SCHEMA2','SCHEMA3', 'SCHEMA4', 'SCHEMA5') then
execute immediate 'grant create role, create public synonym, create view, drop any role, create trigger, create table, '||
'create sequence to '||v_varchar_user;
DBMS_OUTPUT.PUT_LINE('grant create role, create public synonym, create view, drop any role, create trigger, create table, '||
'create sequence to '||v_varchar_user);

end if;
-- if the user already exists do nothing
else DBMS_OUTPUT.PUT_LINE('user already exist');
end if;

-- just to add a empty line between users for readability
DBMS_OUTPUT.PUT_LINE(' ');
 end loop;

end;
/