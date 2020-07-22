'''
.py file for gathering the information of child sponsorship
potential recipients from publicly-available child-specific
information pages. Also keeps track of their match statuses.
'''

## importing necessary modules
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from bs4 import BeautifulSoup as BSoup
from joblib import Parallel, delayed
from scrape_urls import all_page_finder
from selenium.common.exceptions import NoSuchElementException
from selenium.common.exceptions import TimeoutException

import time
import re
import pandas as pd
import numpy as np
import multiprocessing

## use sortorder=0 if general, =3 if longest waiting
base_url = ('https://www.compassion.com/sponsor_a_child/'
            'view-all-children.htm?HvcMismatch=false&'
            'NumberRequested=72&CurrentPage={}&'
            'SortOrder=0&BirthdayTodayFilter=false')

## change where the chromedriver actually is
execute_here = r'chromedriver.exe'

## options for the ChromeDriver
options = webdriver.ChromeOptions()
options.add_argument('--ignore-certificate-errors')
options.add_argument('--ignore-ssl-errors')

## multiprocessing for parallelization
cpu_count = multiprocessing.cpu_count()

def child_info_finder(child_url, sleeptime=4, close=True):
    '''
    Getting the information of a single child

    Input:
    - child_url (str / tuple): URL for the child-specific page;
        if not str, the first element of tuple should contain the
        str-valued URL
    - sleeptime (int / float): time for the page to fully load
    - close (boolean): for closing the Driver or not

    Output:
    - If successfully done, returns a list of URL and child-specific
        information; if not, a list of URL and error message is
        returned

    '''
    if type(child_url) == str:
        url = child_url
    else:
        url = child_url[0]
    
    try:
        driver = webdriver.Chrome(executable_path=execute_here,
                                  options=options)
        driver.get(url)
        time.sleep(sleeptime)
    
        secondtab = driver.find_elements_by_class_name('js-bio-community-content')
        if len(secondtab) == 0:
            noinfo = True
            try:
                anyinfo = driver.find_element_by_class_name('no-js').text
            except NoSuchElementException:
                time.sleep(sleeptime)
                try:
                    anyinfo = driver.find_element_by_class_name('no-js').text
                except NoSuchElementException:
                    if close:
                        driver.close()
                    return [url, 'error']
        
            if 'could not be found' in anyinfo:
                anyinfo_msg = 'could_not_be_found_msg'
            elif 'sponsored by someone else' in anyinfo:
                anyinfo_msg = 'sponsor_found_msg'
            else:
                anyinfo_msg = anyinfo
        
            if close:
                driver.close()
            return [url, anyinfo_msg]
        
        else:
            secondtab_info = secondtab[0].get_attribute('innerHTML')
            secondtab_soup = BSoup(secondtab_info, 'html.parser')
            secondtab_info_lst = [i.text for i in secondtab_soup.find_all('p')]
            noinfo = False
        
            maininfo_finder = driver.find_elements_by_class_name('clearfix')
            maintab_info = maininfo_finder[0].text
    
            if close:
                driver.close()
    
        return [url, maintab_info, secondtab_info_lst]

    except TimeoutException:
        return [url, 'timeout_error']
    
    except NoSuchElementException:
        return [url, 'nosuch_error']
    
def all_children_info_finder(urls=None, sleeptime=4, njobs=cpu_count):
    '''
    Finds information about all children currently posted
    
    Inputs:
    - urls (list): list of tuples whose first elements are URLs, or simply
        list of URLs; if None, will conduct the URL search first before
        searching for child-specific info
    - sleeptime (int/float): waiting time for children information finding
    - njobs (int): number of cores/threads for parallelization

    Outputs:
    - results as a list containing children-specific information or
        error messages (if any search failed).         
    '''    

    if urls is None:
        print('Gathering urls...')
        urls = all_page_finder(njobs=cpu_count)
        print()
    
    t = time.time()
    print("Getting children's info...")
    results = Parallel(n_jobs=njobs)(
        delayed(child_info_finder)(url, sleeptime, True) for url in urls)
    t1 = round(time.time() - t, 4)
    print('It took {} seconds...'.format(t1))
    
    return results

def child_info_updater(child_url, child_id, sleeptime=3, close=True):
    '''
    Updater for the match status of a child. Detects whether one was
    matched, or if there seems to be a change in the URL so that
    the child is no longer trackable (or simply not matched yet)

    Input:
    - child_url (str / tuple): URL for the child-specific page;
        if not str, the first element of tuple should contain the
        str-valued URL
    - child_id (str): child-specific ID indicated by the website
    - sleeptime (int / float): time for the page to fully load
    - close (boolean): for closing the Driver or not

    Output:
    - information about the URL and whether the child has been
        matched / still unmatched / disappeared from the dataset
        is returns as a list.
    '''
    if type(child_url) == str:
        url = child_url
    else:
        url = child_url[0]

    try:
        driver = webdriver.Chrome(executable_path=execute_here,
                                  options=options)    
        driver.get(url)
        time.sleep(sleeptime)

        secondtab = driver.find_elements_by_class_name('js-bio-community-content')
        if len(secondtab) == 0:
            noinfo = True
            try:
                anyinfo = driver.find_element_by_class_name('no-js').text
            except NoSuchElementException:
                time.sleep(sleeptime)
                try:
                    anyinfo = driver.find_element_by_class_name('no-js').text
                except NoSuchElementException:
                    if close:
                        driver.close()
                    return [url, 'error']

            if 'could not be found' in anyinfo:
                anyinfo_msg = 'could_not_be_found_msg'
            elif 'sponsored by someone else' in anyinfo:
                anyinfo_msg = 'sponsor_found_msg'
            else:
                anyinfo_msg = anyinfo

            if close:
                driver.close()
            return [url, anyinfo_msg]

        else:
            maininfo_finder = driver.find_elements_by_class_name('clearfix')
            maintab_info = maininfo_finder[0].text

            if child_id in maintab_info:
                rtn = [url, 'unmatched']
            else:
                rtn = [url, 'error_unable_to_locate_original']

            if close:
                driver.close()

            return rtn
    except TimeoutException:
        
        return [url, 'timeout_error']
    
    except NoSuchElementException:
        return [url, 'nosuch_error']
    
def all_children_info_updater(urls, ids, sleeptime=3, njobs=cpu_count):
    '''
    Information about all children in the original dataset
    to be updated by this function.
    
    Inputs:
    - urls (list): list containing URLs of specific pages
        to be updated
    - ids (list): list ofchild-specific IDs indicated by the website
    - sleeptime (int / float): time for the page to fully load
    - njobs (int): number of cores/threads for parallelization
    '''
    urls_and_ids = np.vstack([urls, ids]).T
    
    t = time.time()
    print("Getting children's info...")
    results = Parallel(n_jobs=njobs)(
        delayed(child_info_updater)(
            ui[0], ui[1], sleeptime, True) for ui in urls_and_ids)
    t1 = round(time.time() - t, 4)
    print('It took {} seconds...'.format(t1))
    
    return results
