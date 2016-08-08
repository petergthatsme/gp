#!/usr/bin/python

#author: peter g

#This program will grab paper from arxiv.org given a url to the main paper page. It will parse the page
#to grab the paper's title, and the author's names and create an appropriate file name.
#It is meant to simplify this process, but it should not be abused, as I am not sure how keen
#arxiv.org is on having people grab papers via automated means. 


#TODO:
#shorten author names in a nice way when file names end up being too long

import unicodedata 
import urllib
import shutil
import re
from sys import exit
from xml.dom import minidom
from optparse import OptionParser
from os.path import expanduser
from os.path import exists
from os.path import join

baseDir=join(expanduser("~") ,"Dropbox/papers_and_docs/")

usage = '%prog [options] url1 url2 ...'
version = '%prog 0.1'

parser = OptionParser(usage=usage, version=version)
parser.add_option("-r", "--rebuild", action='store',
                  help="Redownloads all the publications from the database file", metavar="FILE")
parser.add_option("-o", "--overwrite", action='store_true',
                  help="Re-download paper even if already present in database.")
opts, args = parser.parse_args()

def arxivPaper(url):

    f = urllib.urlopen(url)
    html = f.read()

    #HACK: seems the ending tag is broken as of right now - just grab the header, all info there anyway
    #there has to be a prettier way to do this!
    html=html[0:html.find("</head>")]+"</head>\n</html>"
    #broken as of Aug 4, 2016
    html=html.replace(r'<meta name="viewport" content="width=device-width, initial-scale=1">', '')
    html=html.replace(r'<meta http-equiv="X-UA-Compatible" content="IE=edge">', '')

    xmldoc = minidom.parseString(html)
    metaList=xmldoc.getElementsByTagName('meta')

    docInfo=dict(authors=[], title='', url='', pId='')

    for x in metaList:
        n,c=x.attributes['name'].value, x.attributes['content'].value
        #print(n,c)
        if n=='citation_author':
            docInfo['authors'].append(c.replace(" ", "_").replace(",", "").replace(".",""))
        if n=='citation_pdf_url':
            docInfo['url']=c.replace(" ", "_")
        if n=='citation_title':
            docInfo['title']=c.replace(" ", "_").replace(",", "").replace("/", "_")
        if n=='citation_arxiv_id':
            docInfo['pId']="arxiv_%s" % c.replace(" ", "_").replace(",", "").replace("/", "_")

        #print(x.attributes.keys())
        #print(x.attributes['name'].value, x.attributes['content'].value)

    #print(docInfo)

    fileName="%s-%s-%s.pdf" % (docInfo['title'], "-".join(docInfo['authors']), docInfo['pId'])
    fileName=unicodedata.normalize('NFKD',fileName).encode('ascii','ignore')

    print("Url: %s\nFile: %s" % (url, fileName))
    print(docInfo['url'])

    #change the user-agent as arxiv wont let urllib grab the file.
    class AppURLopener(urllib.FancyURLopener):
        version = "Lynx"
    AppURLopener().retrieve(docInfo['url'], join(baseDir, fileName))

    return fileName

def isInFile(url, fileName):

    if not exists(fileName):
        return False
    
    lines=map(getUrlFromInfo, file(fileName, 'r').readlines())

    if url in lines:
        return True
    
    return False

def getUrlFromInfo(text):
    #expect text to be:
    #url title
    return (text.rstrip('\n')).split(" ")[0]

if __name__=="__main__":

    dbFileName=join(baseDir, "all.txt")
    
    if opts.rebuild:
        dbFileName=(baseDir, opts.rebuild)
        urls=map(getUrlFromInfo, file(dbFileName, 'r').readlines())
        shutil.move(dbFileName, join(dbFileName, ".bak"))
    else:
        urls=args

    for url in urls:
        isInDatabase=isInFile(url, dbFileName)

        if not isInDatabase or opts.overwrite:

            if "arxiv.org" in url:
                fileName=arxivPaper(url)
            #elif "aps.org" in url:
                #fileName=apsPaper(url)
            else:
                print("Don't know how to get paper from '%s'" % url)
                continue

            if not isInDatabase:
                print("Adding '%s' to %s" % (url, dbFileName))
                file(dbFileName, 'a').write("%s %s\n" % (url, fileName))
        else:
            print("Paper laready exist in database: %s\n" % url)
           


