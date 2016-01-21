#!/usr/bin/env python
# coding=utf-8

# -----------------------------------------
# Purpose:      SVN增量备份
# Version:      1.0
# BLOG:         http://www.linux178.com
# EMAIL:        chanyipiaomiao@163.com
# Created:      
# Python:       2.4/2.7
#------------------------------------------


import os
from time import strftime
import sqlite3
from sys import argv


# 版本库的根目录和备份的根目录
svn_repo_root = 'E:\\'
svn_backup_root = 'D:\\test\\svn_backup\\increment_backup'

# svn_repo_root = 'D:\\svnrepo\\'
# svn_backup_root = 'Z:\\252_svn\\increment_backup'

# svn_repo_root = 'D:\\svnrepo\\'
# svn_backup_root = 'Z:\\217_svn\\increment_backup'

# 数据库文件所在的目录是 脚本所在的目录
script_dir =  os.path.dirname(argv[0])

db_name = script_dir +'\\svn_full_backup_217.db'
# db_name = script_dir +'\\svn_full_backup_252.db'



# 查询全量备份的版本号
select_full_increment_number = '''
    SELECT
        repo_name,
        full_backup_version_number,
        last_increment_version_number
    FROM
        full_backup
    WHERE
        repo_name = '%s'
    AND
        is_new_full_back = 1
'''


# 更新sql
update_increment_number = '''
    UPDATE
        full_backup
    SET
        last_increment_version_number = '%s'
    WHERE
        repo_name = '%s'
    AND
        is_new_full_back = 1
'''


# 获取当天的日期
def get_date():
    return strftime('%Y-%m-%d')


# 获取当天的日期和时间
def get_time():
    return strftime('%H-%M-%S')


# 新建目录
def create_dir(name):
    os.mkdir(name)


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


# 要备份的版本库列表
def get_backup_repo_list(repo_root):
    backup_repo_list = []
    # 得到要备份的版本库
    for i in os.listdir(repo_root):
        if os.path.exists(repo_root + '\\' + i + '\\conf\\svnserve.conf'):
            backup_repo_list.append(i)
    return backup_repo_list


if test_dir_is_writable(svn_backup_root):

    # 切换至备份根目录
    os.chdir(svn_backup_root)
    current_backup_dir = 'increment_backup_%s' % get_date()

    # 新建当天目录
    if not os.path.exists(current_backup_dir):
        create_dir(current_backup_dir)

    # 打开数据库连接
    conn = sqlite3.connect(db_name)
    cur = conn.cursor()


    # 新建 时间目录，每天都会有比较多的增量备份
    os.chdir(current_backup_dir)
    time_dir = get_time()


    for repo_name in get_backup_repo_list(svn_repo_root):
        repo_abs_path = svn_repo_root + repo_name
        cur.execute(select_full_increment_number % repo_name)
        result = cur.fetchone()
        if result:
            full_number = result[1]
            increment_number = result[2]

            # 获取当前最新的版本号
            svn_youngest_number = os.popen("svnlook youngest %s" % repo_abs_path).read().strip()

            # 如果最新的版本号 和 全量备份时的版本号一样，则不用备份跳过
            if full_number == svn_youngest_number or increment_number == svn_youngest_number:
                continue

            if not os.path.exists(time_dir):
                create_dir(time_dir)

            command_status = os.system('svnadmin dump %s -r %s:%s --incremental > %s\\%s.dumpfile' %
                                       (repo_abs_path,full_number,svn_youngest_number,
                                        time_dir,repo_name + "_" + full_number + "-" + svn_youngest_number))
            if command_status == 0:
                cur.execute(update_increment_number % (svn_youngest_number,repo_name))
                conn.commit()

    cur.close()
    conn.close()