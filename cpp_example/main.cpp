#include <iostream>

using namespace std;


void test_function(){
    for(int i; i<10; i++){
       int new_i = i+100;
       new_i += 5;
    }
}


int main()
{
    cout<<"Hello World";
    test_function();
    cout << "It is end of the code!";


    return 0;
}
