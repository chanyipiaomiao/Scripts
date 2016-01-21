#!/usr/bin/env python
# coding=utf-8


import os
import re
import urllib
import logging
import pickle
import HTMLParser
import MySQLdb
import BeautifulSoup



# 下载页面
def downloadPage(url, filename):
    download_ok = False
    urllib.urlretrieve(url, filename)
    if os.path.getsize(filename) > 2048:
        download_ok = True
    return download_ok


# 读取下载好的页面
def readHtmlContent(filename):
    html_file = open(filename, 'r')
    html = html_file.read()
    html_file.close()
    data = BeautifulSoup.BeautifulSoup(html)
    return data


# 分析页面文件，找出想要的字段
def parseHtml(product_filename, description_filename):

    data = readHtmlContent(product_filename)
    description = readHtmlContent(description_filename)
    ASIN = os.path.splitext(os.path.basename(product_filename))[0]
    book_dict[ASIN] = {}.fromkeys(book_filed_list, '')
    result_list  = []
    result_list.append(ASIN)
    ok = 'OK'
    error = 'Error'


    # 获取书名及作者
    try:
        namestring = u' [书名,作者及包装]分析..%s '
        get_book_name_author = data.findAll('div',{'class':'buying'})
        for i in get_book_name_author:
            if i.h1:
                book_name_author = i.getText()
        book_name_author_list = book_name_author.split(']')
        book_dict[ASIN]['BOOK_NAME'] = book_name_author_list[0].split('[')[0]
        book_dict[ASIN]['PACK'] = book_name_author_list[0].split('[')[1]
        if book_name_author_list[1]:
            book_dict[ASIN]['AUTHOR'] =  book_name_author_list[1].split('~')[1]
        result_list.append(namestring % ok)
    except:
        result_list.append(namestring % error)

    # 获取封面图片
    imgstring = u' [封面下载]..%s '
    try:
        img_url = data.find('div',{'class':'main-image-inner-wrapper'}).img['src']
        img_file = ASIN + "\\" + ASIN + '.jpg'
        is_ok = downloadPage(img_url, img_file)
        if is_ok:
            result_list.append(imgstring % ok)
        else:
            result_list.append(imgstring % error)
    except:
        result_list.append(imgstring % error)


    # 获取价格
    pricestring = u' [定价及售价]分析..%s '
    try:
        p_market = re.compile(u'市场价')
        p_order = re.compile(u'定价|价格')
        p_price = re.compile(',')
        get_book_price_html = data.find('div',{'class':'buying','id':'priceBlock'})
        if get_book_price_html:
            get_book_price = get_book_price_html.findAll('tr')[0:2]
            for i in get_book_price:
                price_list = i.getText().split()
                if p_market.match(price_list[0]):
                    book_dict[ASIN]['PAPER_PRICE']  =  price_list[1]
                    if "," in book_dict[ASIN]['PAPER_PRICE']:
                        book_dict[ASIN]['PAPER_PRICE'] = p_price.sub('',book_dict[ASIN]['PAPER_PRICE'])
                elif p_order.match(price_list[0]):
                    book_dict[ASIN]['PAPER_SALE_PRICE'] =  re.match('\d+\.\d{2}',price_list[1]).group()
                    if "," in book_dict[ASIN]['PAPER_SALE_PRICE']:
                        book_dict[ASIN]['PAPER_SALE_PRICE'] = p_price.sub('',book_dict[ASIN]['PAPER_SALE_PRICE'])
            result_list.append(pricestring % ok)
        else:
            book_dict[ASIN]['PAPER_PRICE'] = 0
            book_dict[ASIN]['PAPER_SALE_PRICE'] = 0
            result_list.append(pricestring % error)
    except:
        book_dict[ASIN]['PAPER_PRICE'] = 0
        book_dict[ASIN]['PAPER_SALE_PRICE'] = 0
        result_list.append(pricestring % error)

    # 获取图书描述
    book_description_string = u' [图书描述]分析..%s '
    try:
        p = re.compile(u'年|月|日')
        book_description = data.findAll('div',{'id':'ps-content'})
        press_date_span = book_description[0]('span',{'class':'byLinePipe'})[0]
        book_dict[ASIN]['PUBLISH_DATE'] = re.sub(p, '-', press_date_span.nextSibling.getText())[0:-1]     # 出版日期
        description_div = book_description[0].find('div',{'id':'postBodyPS'})
        introduction = description_div.getText()                # 简介
        if '&#' in introduction:
            book_dict[ASIN]['INTRODUCTION'] = entry.unescape(introduction)
        else:
            book_dict[ASIN]['INTRODUCTION'] = introduction
        result_list.append(book_description_string % ok)
    except:
        result_list.append(book_description_string % error)

    # 获取基本信息
    basic_info_string =u' [图书基本信息]分析..%s '
    try:
        basic_info = data.find('td',{'class':'bucket'})
        li_list = basic_info.ul.findAll('li')
        for li in li_list:
            text = li.getText()
            if ':' in text:
                key,value = text.split(':', 1)
                if key in u"出版社":                                                 # 出版社
                    if ';' in value:
                        book_dict[ASIN]['PUBLISHER_NAME'] = value.split(';')[0]
                        book_dict[ASIN]['PUBLISH_VERSION'] = value.split(';')[1].split()[0]  # 版次
                    else:
                        book_dict[ASIN]['PUBLISHER_NAME'] = value.split()[0]
                        version_list = value.split()[1].split()
                        if len(version_list) > 2:
                            book_dict[ASIN]['PUBLISH_VERSION'] = version_list[0]
                elif key in u"开本":                                                # 开本
                    book_dict[ASIN]['FOLIO'] = value
                elif key == "ISBN":                                                 # ISBN
                    book_dict[ASIN]['ISBN'] = value
                elif key in u"条形码":                                              # 条形码
                    book_dict[ASIN]['BARCODE'] = value
                elif key in u"商品尺寸":                                            # 商品尺寸
                    book_dict[ASIN]['PACKAGE_SIZE'] = value
                elif key in u"商品重量":                                            # 商品重量
                    book_dict[ASIN]['PACKAGE_WEIGHT'] = value
                elif key in u"平装":                                                # 页数
                    book_dict[ASIN]['FACT_PAGE_COUNT'] = 0
                    page = value[0:-1]
                    if page:
                        book_dict[ASIN]['FACT_PAGE_COUNT'] = page
                elif key in u"丛书名":                                              # 丛书名
                    if '&nbsp;' in value:
                        book_dict[ASIN]['BOOK_SERIES'] = value.split(';')[1]
                    else:
                        book_dict[ASIN]['BOOK_SERIES'] = value
                elif key in u"外文书名":                                            # 外文书名
                    if '&nbsp;' in value:
                        book_dict[ASIN]['ORIGINAL_BOOK_NAME'] = value.split(';')[1]
                    else:
                        book_dict[ASIN]['ORIGINAL_BOOK_NAME'] = value
            elif u'：' in text:
                key,value = text.split(u'：', 1)
                if key in u"语种":                                                  # 语种
                    book_dict[ASIN]['LANGUAGE'] = value
            else:
                pass
        result_list.append(basic_info_string % ok)
    except:
        book_dict[ASIN]['FACT_PAGE_COUNT'] = 0
        result_list.append(basic_info_string % error)


    # 获取商品描述
    productDescription_string = u' [商品详细页面]分析..%s '
    try:
        productDescription_section = description.find('div',{'id':'productDescription'})
        WriterRecommendAuthor = productDescription_section.findAll('h3')
        WriterRecommendAuthorContent = productDescription_section.findAll('div',{'class':'productDescriptionWrapper'})
        for i,j in zip(WriterRecommendAuthor,WriterRecommendAuthorContent) :
            key = i.getText()
            value = u''.join([unicode(x) for x in j.contents[0:-2]]).strip()
            if key in u"编辑推荐":
                if '&#' in value:
                    book_dict[ASIN]['EDITOR_COMMENT'] = entry.unescape(value)
                else:
                    book_dict[ASIN]['EDITOR_COMMENT'] = value
            elif key in u"目录":
                if '&#' in value:
                    book_dict[ASIN]['TABLE_OF_CONTENTS'] = entry.unescape(value)
                else:
                    book_dict[ASIN]['TABLE_OF_CONTENTS'] = value
            elif key in u"作者简介":
                if '&#' in value:
                    book_dict[ASIN]['AUTHOR_INTRODUCTION'] = entry.unescape(value)
                else:
                    book_dict[ASIN]['AUTHOR_INTRODUCTION'] = value
        result_list.append(productDescription_string % ok)
    except:
        result_list.append(productDescription_string % error)

    return result_list


# 获取文件大小
def getSize(filename):
    is_ok = True
    if os.path.getsize(filename) < 61440:
        is_ok = False
    return is_ok


# 连接Mysql
def connMysql(host, user, passwd, db, port):
    conn = None
    try:
        conn = MySQLdb.connect(host=host, user=user, passwd=passwd, db=db, port=port, charset='utf8')
    except MySQLdb.Error,e:
        print "Mysql Error [ %d ]: %s" % (e.args[0], e.args[1])
    return conn


# 执行SQL语句
def execSQL(cursor, sql):
    try:
        cursor.execute(sql)
        print "OK !!"
    except:
        print "Failure !!"


# 打开日志文件并返回文件对象
def openLogFile(filename, mode):
    data = open(filename,mode)
    return data


# 把分析后形成的字典写入到文件
def dumpBookDictToFile(book_dict,filename):
    data = openLogFile(filename,'w')
    pickle.dump(book_dict,data)
    data.close()


# 把写入到文件的字典读取出来
def loadBookDictFromFile(filename):
    data = openLogFile(filename,'r')
    book_dict = pickle.load(data)
    data.close()
    return book_dict



# 程序开始


# 定义数据库IP、用户名、密码、端口
host = 'localhost'
user = 'root'
passwd = '123456'
db = 'download_book'
port = 3306


# 定义存放书籍信息的字典
book_dict = {}

# 初始化一个HTMLParser实例，来转换HTML实体编码
entry = HTMLParser.HTMLParser()


# 定义书的根目录并切换至该目录
book_root = "D:\\Test\\book"
# book_root = "D:\\AMAZON_BOOK"
os.chdir(book_root)


# 定义日志文件根目录
log_file_root = 'D:\\logs'
# log_file_root = 'D:\\amazon_book_log'
if not os.path.exists(log_file_root):
    os.makedirs(log_file_root)


# 生成的字典写入到文件
book_dict_file = os.path.join(log_file_root,'amazon_book_dict.log')
log_filename = os.path.join(log_file_root,'amazon_book_parse_html.log')


# 定义程序输出的日志文件
format_string = '%(asctime)s %(message)s'
logging.basicConfig(filename=log_filename, level=logging.INFO, format=format_string, filemode='w')
console = logging.StreamHandler()
console.setLevel(logging.INFO)
console.setFormatter(logging.Formatter(format_string))
logging.getLogger('').addHandler(console)


# 定义书的字段
book_filed_list = ['BOOK_NAME','BOOK_SERIES','ORIGINAL_BOOK_NAME','AUTHOR','PUBLISHER_NAME',
                   'PUBLISH_DATE','PUBLISH_VERSION','ISBN','BARCODE','FACT_PAGE_COUNT',
                   'FOLIO','PACK','INTRODUCTION','AUTHOR_INTRODUCTION','EDITOR_COMMENT',
                   'TABLE_OF_CONTENTS','PAPER_PRICE','LANGUAGE','PACKAGE_SIZE','PACKAGE_WEIGHT',
                   'TRANSLATOR','PAPER_SALE_PRICE',
                   ]



# 遍历书的根目录
for dirpath, dirnames, filenames in os.walk('.'):
    if filenames:
        asni = os.path.basename(dirpath)
        product_filename = os.path.join(dirpath, asni + ".html")
        description_filename = os.path.join(dirpath, asni + "_description.html")
        if getSize(product_filename) and getSize(description_filename):
            result =  parseHtml(product_filename, description_filename)
            ok = ''.join(result)
            logging.info("<INFO> " + ok)
        else:
            error = u"<ERROR> %s 文件不完整,跳过分析!!" % asni
            logging.info(error)


# 把生成的字典dump到文件
dumpBookDictToFile(book_dict,book_dict_file)


# 加载文件中的字典
# book_dict = loadBookDictFromFile(book_dict_file)


# 更新语句
update_string = """
    UPDATE
        Test_copy_copy
    SET
        BOOK_NAME='%s',BOOK_SERIES='%s',ORIGINAL_BOOK_NAME='%s',AUTHOR='%s',
        PUBLISHER_NAME='%s',PUBLISH_DATE='%s',PUBLISH_VERSION='%s',ISBN='%s',BARCODE='%s',
        FACT_PAGE_COUNT=%s,FOLIO='%s',PACK='%s',INTRODUCTION='%s',AUTHOR_INTRODUCTION='%s',
        EDITOR_COMMENT='%s',TABLE_OF_CONTENTS='%s',PAPER_PRICE=%s,LANGUAGE='%s',PACKAGE_SIZE='%s',
        PACKAGE_WEIGHT='%s',TRANSLATOR='%s',PAPER_SALE_PRICE=%s,PARSE_OK=%d
    WHERE
        ASIN = '%s'
    """


# 连接到MySQL更新数据
conn = connMysql(host, user, passwd, db, port)
pattern = re.compile("'")
price_pattern = re.compile(",")
if conn:
    cur = conn.cursor()
    for key,value in book_dict.iteritems():
        if "'" in value['BOOK_NAME']:
            value['BOOK_NAME'] = pattern.sub("\\'",value['BOOK_NAME'])
        if "'" in value['AUTHOR']:
            value['AUTHOR'] = pattern.sub("\\'",value['AUTHOR'])
        if "'" in value['BOOK_SERIES']:
            value['BOOK_SERIES'] = pattern.sub("\\'",value['BOOK_SERIES'])
        if "'" in value['ORIGINAL_BOOK_NAME']:
            value['ORIGINAL_BOOK_NAME'] = pattern.sub("\\'",value['ORIGINAL_BOOK_NAME'])
        if '&#' in value['INTRODUCTION']:
            value['INTRODUCTION'] = entry.unescape(value['INTRODUCTION'])
        if "'" in value['INTRODUCTION']:
            value['INTRODUCTION'] = pattern.sub("\\'",value['INTRODUCTION'])
        if '&#' in value['AUTHOR_INTRODUCTION']:
            value['AUTHOR_INTRODUCTION'] = entry.unescape(value['AUTHOR_INTRODUCTION'])
        if "'" in value['AUTHOR_INTRODUCTION']:
            value['AUTHOR_INTRODUCTION'] = pattern.sub("\\'",value['AUTHOR_INTRODUCTION'])
        if '&#' in value['EDITOR_COMMENT']:
            value['EDITOR_COMMENT'] = entry.unescape(value['EDITOR_COMMENT'])
        if "'" in value['EDITOR_COMMENT']:
            value['EDITOR_COMMENT'] = pattern.sub("\\'",value['EDITOR_COMMENT'])
        if '&#' in value['TABLE_OF_CONTENTS']:
            value['TABLE_OF_CONTENTS'] = entry.unescape(value['TABLE_OF_CONTENTS'])
        if "'" in value['TABLE_OF_CONTENTS']:
            value['TABLE_OF_CONTENTS'] = pattern.sub("\\'",value['TABLE_OF_CONTENTS'])
        if not value['FACT_PAGE_COUNT']:
            value['FACT_PAGE_COUNT'] = 0
        if not value['PAPER_PRICE']:
            value['PAPER_PRICE'] = 0
        if not value['PAPER_SALE_PRICE']:
            value['PAPER_SALE_PRICE'] = 0
        if len(value['PUBLISH_DATE']) < 4 or len(value['PUBLISH_DATE']) > 11:
            value['PUBLISH_DATE'] = '2000-01-01'
        if "," in str(value['PAPER_PRICE']):
            value['PAPER_PRICE'] = price_pattern.sub('',str(value['PAPER_PRICE']))
        if "," in str(value['PAPER_SALE_PRICE']):
            value['PAPER_SALE_PRICE']= price_pattern.sub('',str(value['PAPER_SALE_PRICE']))
        update_sql = update_string % (value['BOOK_NAME'], value['BOOK_SERIES'], value['ORIGINAL_BOOK_NAME'], value['AUTHOR'],
                                      value['PUBLISHER_NAME'], value['PUBLISH_DATE'],value['PUBLISH_VERSION'], value['ISBN'],
                                      value['BARCODE'],value['FACT_PAGE_COUNT'],value['FOLIO'], value['PACK'],
                                      value['INTRODUCTION'], value['AUTHOR_INTRODUCTION'],value['EDITOR_COMMENT'],
                                      value['TABLE_OF_CONTENTS'], value['PAPER_PRICE'], value['LANGUAGE'],value['PACKAGE_SIZE'],
                                      value['PACKAGE_WEIGHT'], value['TRANSLATOR'],value['PAPER_SALE_PRICE'], 1, key)
        print update_sql
        print "[%s] update : " % key,
        execSQL(cur, update_sql)
        conn.commit()
    cur.close()
    conn.close()



