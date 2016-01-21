#!/usr/bin/env python
# coding=utf-8


import os
import time
import socket
import urllib
import MySQLdb



# 下载进度
def reportHook(blocks_read, block_size, total_size):
    if not blocks_read:
        print 'Connection opened'
        return
    if total_size < 0:
        print 'Read %d blocks (%d bytes)' % (blocks_read, blocks_read * block_size)
    else:
        amount_read = blocks_read * block_size
        print 'Read %d blocks, or %d/%d' % (blocks_read, amount_read, total_size)
    return


# 下载页面
def downloadPage(url, filename):
    urllib.urlretrieve(url, filename, reporthook=reportHook)


# 创建书ID目录
def createDir(dir_name):
    if not os.path.exists(dir_name):
        os.mkdir(dir_name)


# 判断下载的文件是否存在且大小不为0
def existsFile(file_name):
    if os.path.exists(file_name) and os.path.getsize(file_name) > 102400:
        return True
    return False


# 执行查询语句，并返回结果
def fetchAllResult(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchall()


# 执行更新语句
def updateSQL(cursor, sql):
    cursor.execute(sql)


# 开始下载页面
def startDownLoad(conn, start_asni, error_file):

    # 开始下载商品页面和商品详细页面
    print
    print "-------start download: < %s > --------" % start_asni
    updateSQL(cur, set_downloading_sql % start_asni)
    conn.commit()
    product_file_name = start_asni + '.html'
    product_description_file_name = start_asni + '_description.html'
    try:
        downloadPage(product_url % start_asni, product_file_name)
        downloadPage(product_description % start_asni, product_description_file_name)
        if existsFile(product_file_name) and existsFile(product_description_file_name):
            updateSQL(cur, set_success_sql % start_asni)
            conn.commit()
            print "..... Book [%s] download OK..... " % start_asni
        else:
            print "..... Book [%s] download failure, will restart download ..... " % start_asni
            updateSQL(cur, set_failure_sql % start_asni)
            conn.commit()
    except:
        print "******* [ %s ] download exception *******" % start_asni
        print
        updateSQL(cur, set_failure_sql % start_asni)
        conn.commit()
        error_file.write(start_asni + '\n')
        time.sleep(2)
    conn.commit()


# 连接Mysql
def connMysql(host, user, passwd, db, port):
    conn = None
    try:
        conn = MySQLdb.connect(host=host, user=user, passwd=passwd, db=db, port=port, charset='utf8')
    except MySQLdb.Error,e:
        print "Mysql Error [ %d ]: %s" % (e.args[0], e.args[1])
    return conn



# 定义数据库IP、用户名、密码
host = 'localhost'
user = 'root'
passwd = '123456'
db = 'download_book'
port = 3306
book_root = "D:\\AMAZON_BOOK"

socket.setdefaulttimeout(20)

# 商品页面
product_url = 'http://www.amazon.cn/111fsfsdfd/dp/%s'

# 商品详细页面
product_description = 'http://www.amazon.cn/111fsfsdfd/dp/product-description/%s'


# 查询SQL语句
get_notstart_sql = """
    SELECT
        BOOK_ID,ASIN,DOWNLOAD_SUCCESS,IS_DOWNLOADING
    FROM
        AMAZON_BOOK
    WHERE
        DOWNLOAD_SUCCESS = 0 AND IS_DOWNLOADING = 0
    LIMIT 1
    """

# 更新SQL语句
set_downloading_sql = """
    UPDATE
        AMAZON_BOOK
    SET
        IS_DOWNLOADING = 1
    WHERE
        ASIN = '%s'
    """

# 下载成功时更新语句
set_success_sql = """
    UPDATE
        AMAZON_BOOK
    SET
        DOWNLOAD_SUCCESS = 1
    WHERE
        ASIN = '%s'
    """

# 失败时更新语句
set_failure_sql = """
    UPDATE
        AMAZON_BOOK
    SET
        DOWNLOAD_SUCCESS = 0,IS_DOWNLOADING = 0
    WHERE
        ASIN = '%s'
    """


conn = connMysql(host, user, passwd, db, port)
if conn:
    cur = conn.cursor()
    errorlog = open('d:\\error.log','a')

    # 获取书籍标识并下载
    while True:
        os.chdir(book_root)
        start_asni = fetchAllResult(cur, get_notstart_sql)
        conn.commit()

        # 查询结果是否为空
        if start_asni:
            asni = start_asni[0][1]
            createDir(asni)
            os.chdir(asni)
            startDownLoad(conn, asni, errorlog)
        else:
            print
            print "-------- There is no Book page downdload ! ---------"
            break
    errorlog.close()
    cur.close()
    conn.close()
