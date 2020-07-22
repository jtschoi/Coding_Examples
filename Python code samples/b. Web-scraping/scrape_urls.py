'''
.py file for scraping URLs, which contain publicly-available
child-specific information for those in child sponsorship
programs (Compassion International). 
'''

## importing necessary modules
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from bs4 import BeautifulSoup as BSoup
from joblib import Parallel, delayed
from selenium.common.exceptions import NoSuchElementException

import time
import re
import pandas as pd
import numpy as np
import multiprocessing

## for joblib parallelization
cpu_count = multiprocessing.cpu_count()

## use sortorder=0 if general, =3 if longest waiting
base_url = ('https://www.compassion.com/sponsor_a_child/'
            'view-all-children.htm?HvcMismatch=false&'
            'NumberRequested=72&CurrentPage={}&'
            'SortOrder=0&BirthdayTodayFilter=false')

## change where the chromedriver actually is
execute_here = r'chromedriver.exe'

## options for ChromeDriver
options = webdriver.ChromeOptions()
options.add_argument('--ignore-certificate-errors')
options.add_argument('--ignore-ssl-errors')

def get_child_link(element):
    '''
    getting the child's URL
    '''
    
    child_info = element.get_attribute('innerHTML')
    child_soup = BSoup(child_info, 'html.parser')
    child_link = child_soup.find(
        'div', {'class': 'button'}).find('a').get('onclick')
    child_actual_link = re.split('href=', child_link)[1]
    child_actual_link = child_actual_link[1:-1]

    return child_actual_link

def page_link_finder(url_no, sleeptime=12):
    '''
    Getting the entire page's URLs for children.
    
    Input:
    - url_no (int): number of the page, descending in the waitdays
    - sleeptime (float): number of seconds to wait for loading

    Output:
    - list containing the URL and URL number if search is executed
        successfully; empty list if unsuccessful 
    '''

    url_here = base_url.format(url_no)
    driver = webdriver.Chrome(executable_path=execute_here,
                              options=options)
    driver.get(url_here)
    time.sleep(sleeptime)
    
    children = None
    case = True
    while case:
        try:
            children = driver.find_elements_by_class_name('sponsor-child-holder')
            case = False
        except NoSuchElementException:
            pass

    ## if children were found (successful search)
    if children is not None:
        child_htmls = [(get_child_link(i), url_no) for i in children]    
        driver.close()
    
        return child_htmls
    
    ## in case the search process failed
    driver.close()
    return []

def all_page_finder(pages=list(range(1, 140)), njobs=cpu_count):
    '''
    Finds urls across all pages specified (default from pages 1
    to 139)
    
    Inputs:
    - pages (list of ints): pages to search for
    - njobs (int): number of cores/threads to use for the
        scraping process

    Output:
    - list containing the URLs and URL numbers if search is executed
        successfully; empty list if unsuccessful
    '''    

    t = time.time()
    
    incomplete = True
    run = 1
    
    while incomplete:
        results = []
        if run == 1:
            print('First run...')
            results_partial = Parallel(n_jobs=njobs)(
                delayed(page_link_finder)(str(p)) for p in pages)
            
            for res in results_partial:
                results += res
            
            results_df = pd.DataFrame(results)
            pages_done = sorted(list(np.unique(results_df.iloc[:, 1])))
            
            if pages_done == pages:
                incomplete = False
            else:
                remaining = set(pages).difference(set(pages_done))
                remaining = sorted(list(remaining))
            run += 1
        
        else:
            print('Re-running... try no. {}'.format(run))
            results_partial = Parallel(n_jobs=njobs)(
                delayed(page_link_finder)(p) for p in remaining)
            
            for res in results_partial:
                results += res
            
            results_df_tryagain = pd.DataFrame(results)
            pages_done_tryagain = sorted(list(np.unique(
                results_df_tryagain.iloc[:, 1])))
            
            if pages_done_tryagain == pages:
                incomplete = False
            else:
                remaining = set(pages).difference(set(
                    pages_done_tryagain))
                remaining = sorted(list(remaining))
            run += 1
    
    t1 = time.time() - t
    print('Scraping took {} seconds'.format(round(t1, 4)))
    
    return results

def sac_page_link_finder(sleeptime=12):
    '''    
    Gathering URL information from the SAC (sponsor-a-child) page,
    in case it is necessary

    Input:
    - sleeptime (int / float): for waiting until fully loaded

    Output:
    - list containing the URLs and URL numbers if search is executed
        successfully; empty list if unsuccessful
    '''

    sac = 'https://www.compassion.com/sponsor_a_child/'
    driver = webdriver.Chrome(executable_path=execute_here,
                              options=options)
    driver.get(sac)
    time.sleep(sleeptime)
    
    children = None
    case = True
    while case:
        try:
            children = driver.find_elements_by_class_name('sponsor-child-holder')
            case = False
        except NoSuchElementException:
            pass

    if children is not None:
        child_htmls = [get_child_link(i) for i in children]    
        driver.close()
    
        return child_htmls
    
    driver.close()
    return []
