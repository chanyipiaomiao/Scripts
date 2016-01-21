#!/usr/bin/env python
# coding=utf-8

# -----------------------------------------
# Purpose:      SVN全量备份
# Version:      1.0
# BLOG:         http://www.linux178.com
# EMAIL:        chanyipiaomiao@163.com
# Created:
# Python:       2.4/2.7
# ------------------------------------------

import sqlite3
import os
from time import strftime
from sys import argv


# 版本库的根目录和备份的根目录
svn_repo_root = 'E:\\'
svn_backup_root = 'D:\\test\\svn_backup\\full_backup'

# svn_repo_root = 'D:\\svnrepo\\'
# svn_backup_root = 'Z:\\217_svn\\full_backup'

# svn_repo_root = 'D:\\svnrepo\\'
# svn_backup_root = 'Z:\\252_svn\\full_backup'


# 数据库文件所在的目录是 脚本所在的目录
script_dir =  os.path.dirname(argv[0])
db_name = script_dir +'\\svn_full_backup_217.db'
# db_name = script_dir +'\\svn_full_backup_252.db'


# 创建表语句
'''
    DROP TABLE IF EXISTS full_backup;
    CREATE TABLE full_backup (
      full_backup_id  INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      repo_name  TEXT NOT NULL,
      full_backup_date  TEXT NOT NULL,
      is_new_full_back  INTEGER NOT NULL,
      full_backup_version_number  TEXT NOT NULL,
      last_increment_version_number  TEXT NOT NULL,
      start_backup_time  TEXT NOT NULL,
      end_backup_time  TEXT NOT NULL
    )
'''

# 插入语句
insert_new_sql = '''
    INSERT INTO full_backup (
      repo_name,
      full_backup_date,
      is_new_full_back,
      full_backup_version_number,
      last_increment_version_number,
      start_backup_time,
      end_backup_time)
    VALUES(?,?,?,?,?,?,?)
'''

# 更新语句
update_new_sql = '''
    UPDATE
        full_backup
    SET
        is_new_full_back = 0
    WHERE
        is_new_full_back = 1
    AND
        repo_name = '%s'
'''

# 查询语句
select_sql = '''
    SELECT
        repo_name,
        full_backup_date
    FROM
        full_backup
    WHERE
        repo_name = '%s'
'''

# 查询版本号
select_number_sql = '''
    SELECT
        full_backup_version_number
    FROM
        full_backup
    WHERE
        repo_name = '%s'
    AND
        is_new_full_back = 1
'''


# 获取当天的时间
def get_now_time():
    return strftime('%Y-%m-%d %H:%M:%S')


# 获取当天的日期
def get_date():
    return strftime('%Y-%m-%d')


# 新建目录
def create_dir(name):
    os.mkdir(name)


# 要备份的版本库列表
def get_backup_repo_list(repo_root):
    backup_repo_list = []
    # 得到要备份的版本库
    for i in os.listdir(repo_root):
        if os.path.exists(repo_root + '\\' + i + '\\conf\\svnserve.conf'):
            backup_repo_list.append(i)
    return backup_repo_list


# 备份目标目录是否可写
def test_dir_is_writable(backup_root):
    is_writable = True
    try:
        test_file = open(backup_root + "\\test.txt", 'w')
        if not test_file.closed:
            test_file.close()
    except IOError:
        print "Destnination Path Not aviable!"
        is_writable = False
    return is_writable


if test_dir_is_writable(svn_backup_root):

    # 切换至备份根目录
    os.chdir(svn_backup_root)
    current_backup_dir = 'full_backup_%s' % get_date()

    # 新建备份目录
    if not os.path.exists(current_backup_dir):
        create_dir(current_backup_dir)

    # 命令执行结果字典
    result_dict = {}


    conn = sqlite3.connect(db_name)
    cur = conn.cursor()


    # 循环版本库列表
    for repo_name in get_backup_repo_list(svn_repo_root):
        repo_abs_path = svn_repo_root + repo_name
        svn_youngest_number = os.popen("svnlook youngest %s" % repo_abs_path).read().strip()
        # cur.execute(select_number_sql % repo_name)
        # result = cur.fetchone()
        # if result:
        #     last_number = result[0]
        #     if last_number == svn_youngest_number:
        #         continue
        start_backup_time = get_now_time()
        backup_name = current_backup_dir + "\\" + repo_name + "_" + svn_youngest_number
        command_exec_status = os.system("svnadmin hotcopy %s %s" % (repo_abs_path, backup_name))
        if command_exec_status == 0:
            end_backup_time = get_now_time()
            result_dict[repo_name] = {}
            repo_dict = result_dict[repo_name]
            repo_dict['command_exec_status'] = command_exec_status
            repo_dict['start_backup_time'] = start_backup_time
            repo_dict['end_backup_time'] = end_backup_time
            repo_dict['full_backup_svn_number'] = svn_youngest_number
            repo_dict['full_backup_date'] = get_date()


    if result_dict:
        for key, value in result_dict.items():
            cur.execute(select_sql % key)
            if cur.fetchall():
                 cur.execute(update_new_sql % key)
            cur.execute(insert_new_sql, (key, value['full_backup_date'], 1,
                                         value['full_backup_svn_number'],value['full_backup_svn_number'],
                                         value['start_backup_time'], value['end_backup_time']))
            conn.commit()
    cur.close()
    conn.close()
