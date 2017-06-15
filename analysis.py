
import folium
import pandas as pd
import sys
import matplotlib.pyplot as plt
import argparse
 
SF_COORDINATES = (37.76, -122.45)
crimedata = pd.read_csv('SFPD_Incidents_-_Current_Year__2015_.csv')

parser = argparse.ArgumentParser(description='Select crime and day.')
parser.add_argument('crime', nargs='?', default='ASSAULT')
parser.add_argument('day', nargs='?', default = 'Monday')
 
args = parser.parse_args()
crimeselect = args.crime.upper()
dayselect = args.day.title()

def get_filtered_data(day, crime):
    dayselect = [day]
    crimeselect = crime
    daycond = crimedata['DayOfWeek'].isin(dayselect) 
    crimecond = crimedata['Category'] == (crimeselect)

    filtered_crimedata = crimedata[crimecond & daycond]
    return filtered_crimedata

def get_n_crimes(day, crime):
    df = get_filtered_data(day, crime)
    return len(df)


crime_cat = crimedata.Category.unique()
print 'All categories of crimes:\n %s'%crime_cat


#Focus on specific crime and produce plot in Matplotlib
filtered_crimedata = get_filtered_data(dayselect, crimeselect)
df = filtered_crimedata[['X','Y']]
fig = plt.figure(figsize=(8,6))
ax = fig.add_subplot(111)
ax.scatter(filtered_crimedata.X, filtered_crimedata.Y)
plt.title('%s on %ss'%(crimeselect,dayselect))
plt.xlabel('long')
plt.ylabel('lat')
plt.savefig('crime_day_scatter.png')


# Focus on specific crime and produce plot in Folium/Leaflet.JS
## simple map
simple_map = folium.Map(location=SF_COORDINATES, zoom_start=12)
for each in filtered_crimedata.iterrows():
    simple_map.circle_marker(location =[each[1]['Y'],each[1]['X']], radius=10, line_color='#151B54',
                      fill_color='#151B54', fill_opacity=1)
simple_map.save('simple_map.html')


#Cluster map with k-means. Do they match up with neighborhoods?
#Cluster map with k-means. Do they match up with neighborhoods?
import numpy as np
from sklearn.cluster import KMeans
X = filtered_crimedata[['X','Y']]
k=5
model = KMeans(n_clusters=k, random_state=1).fit(X)
y_pred = model.predict(X)

fig = plt.figure(figsize=(8,6))
ax = fig.add_subplot(111)
ax.scatter(df.X, df.Y, c=y_pred)
plt.title('%s on %ss'%(crimeselect,dayselect))
plt.xlabel('long')
plt.ylabel('lat')
plt.savefig('kmeans.png')

def get_spaced_colors(n):
    max_value = 16581375 #255**3
    interval = int(max_value / n)
    colors = [hex(I)[2:].zfill(6) for I in range(0, max_value, interval)]
    
    rgb = [(int(i[:2], 16), int(i[2:4], 16), int(i[4:], 16)) for i in colors]
    return ['#%02x%02x%02x' % rgb_i for rgb_i in rgb]
colors= get_spaced_colors(k)

k_means_map = folium.Map(location=SF_COORDINATES, zoom_start=12)
for i,each in enumerate(filtered_crimedata.iterrows()):
    k_means_map.circle_marker(location =[each[1]['Y'],each[1]['X']], radius=10, line_color=colors[y_pred[i]],
                      fill_color=colors[y_pred[i]], fill_opacity=1)
k_means_map.save('kmeans_map.html')


#Run Diagnostic Statistics
import json
with open('dominostats.json', 'wb') as f:
    f.write(json.dumps({"model_score": '%.2f' %model.score(X), 
      "n_crimes": len(X),
      "crime": crimeselect,
      "day": dayselect }))



