#!/bin/bash
#
#	Tytul:
#		Katalogowanie filmow
#	Autor: 
#		Maciej Kubale
#		nr: 120486
#		Informatyka, sem 4, studia niestacjonarne
#		Systemy Operacyjne
#	Opis:
#		Skrypt umozliwia pobieranie informacji o wskazanym filmie/filmach.
#		Najpierw skrypt probuje sciagac dane z serwisu filmweb.pl, a
#		w przypadku niepowodzenia przeszukuje portal imdb.com
#

function download_info_imdb
{
	variable=${filename%.*} #pozbycie sie rozszerzenia pliku
	variable=${variable// /.} #zamiana białych znaków na kropki

	#Formatowanie Tytułu
	title=$(echo "$variable" | sed -r 's/  */\+/g;s/\&/%26/g;s/\++$//g' )

	#Plik pomocniczy w ktorym zapisana bedzie strona
	temporary_file=$title'.txt'

	#pobranie strony z imdb.com
	lynx -connect_timeout=10 --source "http://www.google.com/search?q=site:imdb.com+%22${title}%22&btnI" > ${temporary_file}

	#Wyodrebnienie wynikow ze strony imdb
	title1=$(grep -m 1 "og:title" "${temporary_file}" | grep -Eo '\".*\"' | sed -e 's/"//g')
	year=$(grep -m 1 "\/year\/" "${temporary_file}" | grep -Eo "[0-9]{4}") 
	rating=$(grep -m 1 -oP "[0-9]\.?[0-9]?\<span class=\"ofTen\"\>/10" "${temporary_file}" | sed -r 's/<.*>//g')
	temp=$(grep "og:description" "${temporary_file}" | sed -e 's/content="/@/g' -e 's/" \/>/@/g' -e 's/\&quot;/\"/g' )
	director=$(echo ${temp} | grep -oP "(?<=Directed by ).*?(?=\. With)")
	plot=$(grep "og:description" "${temporary_file}" | sed -e 's/content="/@/g' -e 's/" \/>/@/g' -e 's/\&quot;/\"/g' | sed -n 's|.*Directed by\(.*\)..*|\1|p')
	
	if [ $plot="" ]
	then
		echo "Nie odnaleziono filmu w serwisie filmweb.pl, ani w imdb.com" > $file1
		#informacja o porazce do raportu
		echo "Film ${variable} nie został odnaleziony w bazie Imdb.com !!!" >> raport.txt
		echo "Sciezka dostępu: ${path}" >> $file1 
	else
		#wypisanie wynikow do pliku
		echo "Title:	${title1}" > $file1
		echo "Dir:	${director}" >> $file1
		echo "Year:	${year}" >> $file1
		echo "Rate:	${rating}" >> $file1
		echo "Plot:	Film by${plot}" >> $file1
		echo "Sciezka dostępu: ${path}" >> $file1 
	fi
}

function download_info
{
	path=${file}
	variable=${filename%.*} #pozbycie sie rozszerzenia pliku
	variable=${variable// /.} #zamiana białych znaków na kropki

	file2=$variable'2.txt'
	file1=$variable'.txt'

	if wget -O $file1 "http://www.filmweb.pl/${variable}"
	then
		#informacja o sukcesie do raportu
		echo "Film ${variable} odnaleziony w bazie filmweb.pl" >> raport.txt 
		#pobranie strony z filmweb.pl
		wget -O $file2 "http://www.filmweb.pl/${variable}"

		#ogranicza obszar danych
		sed -n 's|.*<div class="filmPlot bottom-15"><p class="text">\(.*\)(świat).*|\1|p' $file1 > $file2
		mv $file2 $file1

		#usuwa tagi html
		sed -e 's/<[^>]*>/\n/g; s/&[^;]*;//g' $file1 > $file2
		mv $file2 $file1

		#usuwa nadmiarowe znaki konca linii
		tr -s "[\n]" "[\n]" < $file1 > $file2
		mv $file2 $file1
		#usuwa zbedne iformacje
		sed -i '/oceń twórców/d' $file1

		echo "Sciezka dostępu: ${path}" >> $file1
		
		#konwersja kodowania znakow
		iconv -f ISO-8859-2 -t utf-8 -o  $file1
	else
		#informacja o porazce do raportu
		echo "Film ${variable} nie został odnaleziony w bazie filmweb.pl !!!" >> raport.txt 
		#Dane przekazane do pliku
		echo "Nie odnaleziono filmu w serwisie filmweb.pl" > $file1
		echo "Sciezka dostępu: ${path}" >> $file1
		download_info_imdb;
	fi
}



function choose_file
{
	file=$(dialog --title "Wybierz plik" --stdout --fselect $HOME/ 14 48)
	tail -1 raport.txt | sed 's|^[0-9]*|&|p'
	echo $file >> raport.txt #sciezka pliku
	filename=$(basename -- "$file")
	download_info;
}

function choose_directory
{
	directory=`dialog --stdout --title "Wybierz katalog z filmami" --dselect $HOME/ 14 48`
	find "$directory" -maxdepth 1 -type f \
	\( -name "*.avi" \
	-o -name "*.mp4" \
	-o -name "*.mkv" \
	\) > Znalezione_filmy.txt
	while read title
	do
		file=$title
		tail -1 raport.txt | sed 's|^[0-9]*|&|p'
		echo $file >> raport.txt
		filename=$(basename -- "$file")
		download_info;
	done<Znalezione_filmy.txt
}

function information
{
	dialog --title "Informacje o programie" --msgbox "Katalogowanie filmow\nAutor: Maciej Kubale\nWersja: 1.0" 10 50 
}

function exit_program
{
	dialog --title "Katalogowanie filmow" --msgbox "Zakonczono program" 5 40 
	exit 1
}

if [ ! -x /usr/bin/dialog ] # Brak dialogu
then
	echo "Aby skrypt dzialal poprawnie nalezy zainstalowac dialog"
	exit_program;
fi

while [ 0 ]
do
	choice=`dialog --title "Katalogowanie filmow" --menu "Wybierz opcję:" --stdout 10 65 0\
	 "1" "Wybierz plik z filmem"\
	 "2" "Wybierz katalog aby wyszukać wszystkie filmy"\
	 "3" "Informacje o programie"\
	 "4" "Zakoncz program"`

	if [ "$?" != "0" ] #zakonczenie programu dla "anuluj"
	then
		exit_program
	fi

	case "$choice" in
		"1")	choose_file;;
		"2")	choose_directory;;
		"3")    information;;
		"4")    exit_program;;
	esac
done
