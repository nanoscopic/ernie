\documentclass{scrartcl}
\usepackage{tikz}
\usetikzlibrary{fadings}

%\definecolor{color1}{RGB}{255,0,0}
%\definecolor{color2}{RGB}{0,0,255}
%\definecolor{inv1}{RGB}{255,255,255}
%\definecolor{inv2}{RGB}{255,255,255}

\def\minpage#1{\setbox0\hbox{#1}\dimen0=\ht0\advance\dimen0 by\dp0%
  \special{papersize=\the\wd0,\the\dimen0}\box0\eject}

--COLORS--
\pagenumbering{gobble}

\pgfkeys{%
  /piechartthreed/.cd,
  scale/.code            = {\def\piechartthreedscale{#1}},
  mix color/.code        = {\def\piechartthreedmixcolor{#1}},
  background color/.code = {\def\piechartthreedbackcolor{#1}},
  name/.code             = {\def\piechartthreedname{#1}}
}

\newcommand\piechartthreed[2][]{% 
  \pgfkeys{
    /piechartthreed/.cd,
    scale            = 1,
    mix color        = gray,
    background color = white,
    name             = pc
  }
  \pgfqkeys{/piechartthreed}{#1}
  \begin{scope}[scale=\piechartthreedscale] 
    \begin{scope}[xscale=5,yscale=3]
      % outer fuzz
      \path[
        preaction={
          fill=black,
          opacity=.9,
          path fading=circle with fuzzy edge 20 percent,
          transform canvas={yshift=-15mm*\piechartthreedscale}
        }
      ] (0,0) circle (1cm);
      
      %inner fuzz
      \fill[gray](0,0) circle (0.5cm);  
      \path[
        preaction={
          fill=\piechartthreedbackcolor,
          opacity=.9,
          path fading=circle with fuzzy edge 20 percent,
          transform canvas={yshift=-10mm*\piechartthreedscale}
        }
      ] (0,0) circle (0.5cm);
      \pgfmathsetmacro\totan{0} 
      \global\let\totan\totan 
      \pgfmathsetmacro\bottoman{180} \global\let\bottoman\bottoman 
      \pgfmathsetmacro\toptoman{0}   \global\let\toptoman\toptoman 
      \begin{scope}[draw=black,thin]
        \foreach \an/\col [count=\xi] in {#2}{%
          \def\space{ } 
          \coordinate (\piechartthreedname\space\xi) at (\totan+\an/2:0.75cm); 
          \ifdim 180pt>\totan pt 
            \ifdim 0pt=\toptoman pt
              \shadedraw[
                left color=\col!90!\piechartthreedmixcolor,
                right color=\col!65!\piechartthreedmixcolor,
                draw=black,
                very thin
              ] (0:.5cm) -- ++(0,-3mm) arc (0:\totan+\an:.5cm) 
              -- ++(0,3mm)  arc (\totan+\an:0:.5cm);
              \pgfmathsetmacro\toptoman{180} 
              \global\let\toptoman\toptoman         
            \else
              \shadedraw[
                left color=\col!90!\piechartthreedmixcolor,
                right color=\col!65!\piechartthreedmixcolor,
                draw=black,
                very thin
              ](\totan:.5cm)-- ++(0,-3mm) arc(\totan:\totan+\an:.5cm)
              -- ++(0,3mm)  arc(\totan+\an:\totan:.5cm); 
            \fi
          \fi
          % The surface on top
          \fill[\col!90!gray] 
            (\totan:0.5cm) % inner start
            --(\totan:1cm) % line to outer start
            arc(\totan:\totan+\an:1cm) % outer arc
            --(\totan+\an:0.5cm) % line to center
            arc(\totan+\an:\totan :0.5cm); % inner arc
          % redraw the outer arc since it can be missing
          \draw[black,line width=0.25mm]
            (\totan:1cm)
            arc(\totan:\totan+\an:1cm); % outer arc
          \draw[black, very thin]
            (\totan:0.5cm) % inner start
            --(\totan:1cm); % line to outer start
          \draw[black, very thin]
            (\totan+\an:0.5cm) % inner start
            --(\totan+\an:1cm); % line to outer start
          \pgfmathsetmacro\finan{\totan+\an}
          \ifdim 180pt<\finan pt 
            \ifdim 180pt=\bottoman pt
              % bottom left edge
              \shadedraw[
                left color=\col!90!\piechartthreedmixcolor,
                right color=\col!65!\piechartthreedmixcolor,
                draw=black,
                very thin
              ] (180:1cm) -- ++(0,-3mm) arc (180:\totan+\an:1cm) 
              -- ++(0,3mm)  arc (\totan+\an:180:1cm);
              %\draw[black, thick]
              %  (180:1cm) -- ++(0,-3mm);
              \pgfmathsetmacro\bottoman{0}
              \global\let\bottoman\bottoman
            \else
              % bottom right edge
              \shadedraw[
                left color=\col!90!\piechartthreedmixcolor,
                right color=\col!65!\piechartthreedmixcolor,
                draw=black,
                very thin
              ](\totan:1cm)-- ++(0,-3mm) arc(\totan:\totan+\an:1cm)
              -- ++(0,3mm)  arc(\totan+\an:\totan:1cm); 
              \draw[black,line width=0.15mm]
                (\totan:1cm)-- ++(0,-3mm);
            \fi
          \fi
          \pgfmathsetmacro\totan{\totan+\an}  \global\let\totan\totan 
        }
      \end{scope}
      \draw[thin,black](0,0) circle (0.5cm);
    \end{scope}  
  \end{scope}
}

\begin{document} 
  \begin{tikzpicture}
    \piechartthreed[
      scale=0.7,
      background color=white!50,
      mix color=darkgray
    ]
    --PIEDATA--
    %{45/color1,45/color2,45/red,105/orange,120/yellow}
    % draw the anchor points at the center of each pie slice
    
    %\draw[inv1] (pc 1) node {\Large\textbf{14\%}};
    %\draw[inv2] (pc 2) node {\Large\textbf{18\%}};
  \end{tikzpicture}
\end{document}