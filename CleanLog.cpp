#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <sstream>
#include <algorithm>
#include <iterator>
#include <ctime>

using namespace std;

std::vector<std::string> &split(const std::string &s, char delim, std::vector<std::string> &elems) {
    std::stringstream ss(s);
    std::string item;
    while (std::getline(ss, item, delim)) {
        elems.push_back(item);
    }
    return elems;
}

std::vector<std::string> split(const std::string &s, char delim) {
    std::vector<std::string> elems;
    split(s, delim, elems);
    return elems;
}

void CleanVector(vector<string>& IPs)
{
    time_t now = time(0);
    tm *ltm = localtime(&now);
    int currDay = ltm->tm_mday;
    int currHour = ltm->tm_hour;
    int deleteElem = 0;
    for (std::vector<string>::iterator it = IPs.begin() ; it != IPs.end(); ++it) {
        string line = *it;
        int day = atoi(split(line, ' ')[1].c_str());
        int hour = atoi(split(line, ' ')[2].c_str());
        if (day != currDay && hour < currHour) {
            deleteElem++;
        } else {
            break;
        }
    }
    if (deleteElem > 0) {
         IPs.erase(IPs.begin(),IPs.begin() + deleteElem);
    }
}

int main(int argc, const char * argv[])
{
    string dir = argv[1];
    ifstream in(dir);
    if (!in) {
        cout << "Error read file!" << endl;
        return -1;
    }
    vector<string> IPs;
    string line = "";
    while (!in.eof()) {
        getline(in, line);
        IPs.push_back(line);
    }
    in.close();
    
    CleanVector(IPs);
    
    ofstream out(dir);
    if (!out) {
        cout << "Error read file!" << endl;
        return -1;
    }
    for (std::vector<string>::iterator it = IPs.begin() ; it != IPs.end(); ++it) {
        out << *it;
        out << "\n";
    }
    out.close();
    return 0;
}